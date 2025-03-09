import sys
from collections import InlineArray
from memory import UnsafePointer

from mojix.fd import Fd
from mojix.io_uring import SQE64
from mojix.net.socket import socket, bind, listen
from mojix.net.types import AddrFamily, SocketType, SocketAddrV4
from io_uring import IoUring
from io_uring.buf import BufRing
from io_uring.op import Accept, Read, Write, Recv

alias BYTE = Int8
alias BACKLOG = 512
alias MAX_MESSAGE_LEN = 2048
alias BUFFERS_COUNT = 16  # Must be power of 2
# Number of entries in the submission queue
alias SQ_ENTRIES = 512

alias ACCEPT = 0
alias READ = 1
alias WRITE = 2


@value
@register_passable("trivial")
struct ConnInfo:
    var fd: Int32
    var type: UInt16
    var bid: UInt16  # Buffer ID

    fn __init__(out self, fd: Int32, type: UInt16, bid: UInt16 = 0):
        self.fd = fd
        self.type = type
        self.bid = bid

    fn to_int(self) -> UInt64:
        """Pack ConnInfo into a 64-bit integer for user_data."""
        return (UInt64(self.fd) << 32) | (UInt64(self.type) << 16) | UInt64(self.bid)
        
    @staticmethod
    fn from_int(value: UInt64) -> Self:
        """Unpack ConnInfo from a 64-bit integer."""
        return Self(
            fd=Int32((value >> 32) & 0xFFFFFFFF),
            type=UInt16((value >> 16) & 0xFFFF),
            bid=UInt16(value & 0xFFFF)  # Use lower 16 bits for buffer ID
        )


fn main() raises:
    """Run an echo server using io_uring with ring mapped buffers."""
    args = sys.argv()
    port = Int(args[1]) if len(args) > 1 else 8080
    
    # Initialize io_uring instance with 128 entries
    ring = IoUring(sq_entries=SQ_ENTRIES)

    # Create buffer ring for efficient memory management
    print("Initializing buffer ring with", BUFFERS_COUNT, "entries of size", MAX_MESSAGE_LEN)
    # Use buffer group ID 0 as that's what kernel expects by default
    var buf_ring = ring.create_buf_ring(
        bgid=0,  # Buffer group ID (must be consistent with Recv operation)
        entries=BUFFERS_COUNT,
        entry_size=MAX_MESSAGE_LEN
    )
    
    # Setup listener socket with error handling
    listener_fd = socket(AddrFamily.INET, SocketType.STREAM)
    
    bind(listener_fd, SocketAddrV4(0, 0, 0, 0, port=port))
    listen(listener_fd, backlog=BACKLOG)
    print("Echo server listening on port", port)

    # Add initial accept
    var sq = ring.sq()
    if sq:
        conn = ConnInfo(fd=Int32(listener_fd.unsafe_fd()), type=ACCEPT)
        _ = Accept(sq.__next__(), listener_fd).user_data(conn.to_int())

    # Track active connections
    var active_connections = 0

    # Main event loop
    while True:
        # Submit and wait for at least 1 completion
        submitted = ring.submit_and_wait(wait_nr=1)

        if submitted < 0:
            print("Error: No submissions", submitted)
            break
        
        # Process completions
        for cqe in ring.cq(wait_nr=0):
            res = cqe.res
            user_data = cqe.user_data
            
            conn = ConnInfo.from_int(user_data)
            
            if res < 0:
                print("Error:", res, "on operation type:", conn.type, "fd:", conn.fd)
                continue
            
            # Handle accept completion
            if conn.type == ACCEPT:
                # New connection
                client_fd = Fd(unsafe_fd=res)
                active_connections += 1
                print("New connection (active:", active_connections, ")")

                # Add read for the new connection (using buffer ring)
                # Use a different buffer for each connection (round-robin)
                var next_buffer = UInt16(active_connections % BUFFERS_COUNT)
                print("Assigning buffer", next_buffer, "to connection", client_fd.unsafe_fd())
                _submit_read(client_fd.unsafe_fd(), next_buffer, ring, buf_ring)
                
                # Re-add accept
                sq = ring.sq()
                if sq:
                    accept_conn = ConnInfo(fd=listener_fd.unsafe_fd(), type=ACCEPT)
                    _ = Accept(sq.__next__(), listener_fd).user_data(accept_conn.to_int())
            
            # Handle read completion
            elif conn.type == READ:
                if res <= 0:
                    # Connection closed or error
                    active_connections -= 1
                    print("Connection closed (active:", active_connections, ")")
                else:
                    # Get buffer index directly from the connection info
                    buffer_idx = conn.bid
                    bytes_read = Int(res)
                    print("Read completion (bytes:", bytes_read, ", buffer_idx:", buffer_idx, ")")

                    _submit_write(conn, bytes_read, ring, buf_ring)
                    

            # Handle write completion
            elif conn.type == WRITE:
                # buffer_idx = conn.bid
                print("Write completion (buffer_idx:", conn.bid, ")")

                # Post a new read for the connection
                _submit_read(conn.fd, conn.bid, ring, buf_ring)

    # Clean up
    ring.unsafe_delete_buf_ring(buf_ring^)


# Helper functions

fn _submit_write(conn: ConnInfo, bytes_read: Int, mut ring: IoUring, mut buf_ring: BufRing) raises:
    """Handle read completion by submitting a write one with the bytes read."""
    buffer_idx = conn.bid
    
    # Echo data back using the same buffer
    sq = ring.sq()
    if sq:
        write_conn = ConnInfo(fd=conn.fd, type=WRITE, bid=buffer_idx)
        print("Setting up write with fd:", write_conn.fd, 
              "buffer_idx:", buffer_idx)
        
        # Get a reference to the buffer directly from the ring
        var buf_ring_ptr = buf_ring[]
        var buffer = buf_ring_ptr.unsafe_buf(index=buffer_idx, len=UInt32(bytes_read))
        var buffer_ptr = buffer.buf_ptr
        
        _ = Write(
            sq.__next__(), 
            Fd(unsafe_fd=write_conn.fd), 
            buffer_ptr,
            UInt(bytes_read)
        ).user_data(write_conn.to_int())



fn _submit_read(fd: Int32, buffer_idx: UInt16, mut ring: IoUring, mut buf_ring: BufRing) raises:
    """Handle write completion by submitting a read submission."""
    sq = ring.sq()
    if sq:
        read_conn = ConnInfo(fd=fd, type=READ, bid=buffer_idx)
        
        # Get buffer from the buffer ring
        var buf_ring_ptr = buf_ring[]
        var buffer = buf_ring_ptr.unsafe_buf(index=buffer_idx, len=UInt32(MAX_MESSAGE_LEN))
        var buffer_ptr = buffer.buf_ptr
        
        print("Reading from fd:", fd, "using buffer:", buffer_idx)
        
        _ = Read(
            sq.__next__(), 
            Fd(unsafe_fd=fd),
            buffer_ptr,
            UInt(MAX_MESSAGE_LEN)
        ).user_data(read_conn.to_int())

