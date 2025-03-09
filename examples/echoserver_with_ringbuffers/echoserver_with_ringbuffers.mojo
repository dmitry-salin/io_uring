import sys
from collections import InlineArray
from memory import UnsafePointer

from mojix.fd import Fd
from mojix.io_uring import SQE64, IoUringCqeFlags
from mojix.net.socket import socket, bind, listen
from mojix.net.types import AddrFamily, SocketType, SocketAddrV4
from io_uring import IoUring
from io_uring.op import Accept, Read, Write, RecvMsg
from io_uring.buf import BufRing

alias BYTE = Int8
alias MAX_CONNECTIONS = 16
alias BACKLOG = 512
alias MAX_MESSAGE_LEN = 2048
alias BUFFERS_COUNT = 8  # Must be power of 2
alias BUF_RING_SIZE = BUFFERS_COUNT
# Number of entries in the submission queue
alias SQ_ENTRIES = 128

alias ACCEPT = 0
alias READ = 1
alias WRITE = 2

@value
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
    ring = IoUring[](sq_entries=SQ_ENTRIES)

    # Create buffer ring for efficient memory management
    print("Initializing buffer ring with", BUF_RING_SIZE, "entries of size", MAX_MESSAGE_LEN)
    var buf_ring = ring.create_buf_ring(
        bgid=7,  # Buffer group ID (arbitrary, but must be consistent)
        entries=BUF_RING_SIZE,
        entry_size=MAX_MESSAGE_LEN
    )
    
    # Setup listener socket
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
            flags = cqe.flags
            user_data = cqe.user_data
            
            if res < 0:
                print("Error:", res)
                continue

            conn = ConnInfo.from_int(user_data)
            
            # Handle accept completion
            if conn.type == ACCEPT:
                # New connection
                client_fd = Fd(unsafe_fd=res)
                active_connections += 1
                print("New connection (active:", active_connections, ")")
                
                # Add read for the new connection (using buffer ring)
                sq = ring.sq()
                if sq:
                    read_conn = ConnInfo(fd=client_fd.unsafe_fd(), type=READ)
                    
                    # Use provided buffer group for reading
                    _ = RecvMsg[type=SQE64, origin=__origin_of(sq)](
                        sq.__next__(), 
                        client_fd,
                        UInt32(MAX_MESSAGE_LEN)
                    ).buf_group(7).user_data(read_conn.to_int())
                
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
                    # Check if this is a buffer ring completion
                    if flags & IoUringCqeFlags.BUFFER:
                        # Extract buffer index from flags
                        buffer_idx = BufRing.flags_to_index(flags)
                        bytes_read = Int(res)
                        print("Read completion (bytes:", bytes_read, ", buffer_idx:", buffer_idx, ")")
                        
                        # Get the buffer pointer using the buffer index
                        buf_ring_ptr = buf_ring[]
                        buffer = buf_ring_ptr.unsafe_buf(index=buffer_idx, len=UInt32(bytes_read))
                        
                        # Echo data back
                        sq = ring.sq()
                        if sq:
                            write_conn = ConnInfo(fd=conn.fd, type=WRITE, bid=buffer_idx)
                            _ = Write[type=SQE64, origin=__origin_of(sq)](
                                sq.__next__(), 
                                Fd(unsafe_fd=write_conn.fd), 
                                buffer.buf_ptr,
                                UInt(bytes_read)
                            ).user_data(write_conn.to_int())
                        
                        # Buffer will be automatically recycled when it goes out of scope
                        _ = buffer.into_index()  # Prevent auto-recycling until we're done with Write
            
            # Handle write completion
            elif conn.type == WRITE:
                buffer_idx = conn.bid
                print("Write completion (buffer_idx:", buffer_idx, ")")
                
                # Post a new read for the connection (using buffer ring)
                sq = ring.sq()
                if sq:
                    read_conn = ConnInfo(fd=conn.fd, type=READ)
                    
                    # Use provided buffer group for reading
                    _ = RecvMsg[type=SQE64, origin=__origin_of(sq)](
                        sq.__next__(), 
                        Fd(unsafe_fd=conn.fd),
                        UInt32(MAX_MESSAGE_LEN)
                    ).buf_group(7).user_data(read_conn.to_int())

    # Clean up
    ring.unsafe_delete_buf_ring(buf_ring^)