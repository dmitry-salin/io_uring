import sys
from collections import InlineArray
from memory import UnsafePointer

from mojix.fd import Fd
from mojix.io_uring import SQE64
from mojix.net.socket import socket, bind, listen
from mojix.net.types import AddrFamily, SocketType, SocketAddrV4
from io_uring import IoUring
from io_uring.op import Accept, Read, Write

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
    var bid: UInt32  # Buffer ID

    fn __init__(out self, fd: Int32, type: UInt16, bid: UInt32 = 0):
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
            bid=UInt32(value & 0xFFFF)  # Use lower 16 bits for buffer ID
        )


struct BufferMemory:
    """Manages the buffer memory for the server."""
    var _data: InlineArray[Int8, MAX_MESSAGE_LEN * BUFFERS_COUNT]
    var _buffer_avail: InlineArray[Bool, BUFFERS_COUNT]  # Track buffer availability
    
    fn __init__(out self):
        """Initialize the buffer memory."""
        print("Initializing BufferMemory with direct buffers")
        self._data = InlineArray[Int8, MAX_MESSAGE_LEN * BUFFERS_COUNT](fill=0)
        self._buffer_avail = InlineArray[Bool, BUFFERS_COUNT](fill=True)  # All buffers start as available
    
    fn get_buffer_pointer(self, idx: Int) -> UnsafePointer[BYTE]:
        """Get a pointer to a specific buffer.
        
        Args:
            idx: Buffer index.

        Returns:
            Unsafe pointer to the buffer.
        """
        return self._data.unsafe_ptr() + (idx * MAX_MESSAGE_LEN)
        
    fn get_available_buffer(mut self) -> (Int, UnsafePointer[BYTE]):
        """Get an available buffer.
        
        Returns:
            Tuple of (buffer index, buffer pointer).
        """
        # Find an available buffer
        for i in range(BUFFERS_COUNT):
            if self._buffer_avail[i]:
                self._buffer_avail[i] = False  # Mark as in use
                return (i, self.get_buffer_pointer(i))
                
        # If all buffers are in use, just return the first one
        print("WARNING: All buffers in use, recycling buffer 0")
        return (0, self.get_buffer_pointer(0))
        
    fn mark_buffer_available(mut self, idx: Int):
        """Mark a buffer as available.
        
        Args:
            idx: Buffer index.
        """
        self._buffer_avail[idx] = True
        

fn main() raises:
    """Run an echo server using io_uring with ring mapped buffers."""
    args = sys.argv()
    port = Int(args[1]) if len(args) > 1 else 8080
    
    # Initialize io_uring instance with 128 entries
    ring = IoUring[](sq_entries=SQ_ENTRIES)

    # We'll use separate buffer provider instead of io_uring buffer ring
    # as the buffer ring implementation might have issues
    var buffer_memory = BufferMemory()
    
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
        
        # Process completions
        for cqe in ring.cq(wait_nr=0):
            res = cqe.res
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
                print("New connection: fd=", client_fd.unsafe_fd(), " (active: ", active_connections, ")")
                
                # Add read for the new connection (using direct buffers)
                sq = ring.sq()
                if sq:
                    # Get available buffer
                    var result = buffer_memory.get_available_buffer()
                    var buf_idx = result[0]
                    var buf_ptr = result[1]
                    read_conn = ConnInfo(fd=client_fd.unsafe_fd(), type=READ, bid=UInt32(buf_idx))
                    _ = Read[type=SQE64, origin=__origin_of(sq)](
                        sq.__next__(), 
                        client_fd, 
                        buf_ptr,
                        UInt(MAX_MESSAGE_LEN)
                    ).user_data(read_conn.to_int())
                
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
                    print("Connection closed: fd=", conn.fd, " (active: ", active_connections, ")")
                else:
                    # Get buffer info from the user data
                    buffer_idx = Int(conn.bid)
                    
                    bytes_read = Int(res)
                    print("Read completion: fd=", conn.fd, " bytes=", bytes_read, " buffer_idx=", buffer_idx)
                    
                    # Get the buffer pointer (already provided in connection info)
                    buff_ptr = buffer_memory.get_buffer_pointer(buffer_idx)
                    
                    # Echo data back
                    sq = ring.sq()
                    if sq:
                        write_conn = ConnInfo(fd=conn.fd, type=WRITE, bid=UInt32(buffer_idx))
                        _ = Write[type=SQE64, origin=__origin_of(sq)](
                            sq.__next__(), 
                            Fd(unsafe_fd=write_conn.fd), 
                            buff_ptr,
                            UInt(bytes_read)
                        ).user_data(write_conn.to_int())
            
            # Handle write completion
            elif conn.type == WRITE:
                print("Write completion: fd=", conn.fd)
                
                # Extract buffer index from connection info
                buffer_idx = Int(conn.bid)
                
                # Mark the buffer as available again
                buffer_memory.mark_buffer_available(buffer_idx)
                print("Marked buffer available: idx=", buffer_idx)
                
                # Post a new read for the connection (using direct buffer)
                sq = ring.sq()
                if sq:
                    # Get available buffer
                    var result = buffer_memory.get_available_buffer()
                    var buf_idx = result[0]
                    var buf_ptr = result[1]
                    read_conn = ConnInfo(fd=conn.fd, type=READ, bid=UInt32(buf_idx))
                    _ = Read[type=SQE64, origin=__origin_of(sq)](
                        sq.__next__(), 
                        Fd(unsafe_fd=conn.fd), 
                        buf_ptr,
                        UInt(MAX_MESSAGE_LEN)
                    ).user_data(read_conn.to_int())
