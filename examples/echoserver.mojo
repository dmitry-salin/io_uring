from buffer import Buffer
from memory import UnsafePointer

from mojix.errno import Errno
from mojix.fd import Fd, OwnedFd, UnsafeFd
from mojix.io_uring import SQE64
from mojix.net.socket import socket, bind, listen
from mojix.net.types import AddrFamily, SocketType, SocketAddrV4, SocketFlags
from mojix.timespec import Timespec
from io_uring import IoUring, WaitArg
from io_uring.op import Accept, Read, Write, Nop

alias MAX_CONNECTIONS = 4096
alias BACKLOG = 512 
alias MAX_MESSAGE_LEN = 2048
alias BUFFERS_COUNT = MAX_CONNECTIONS

alias ACCEPT = 0
alias READ = 1
alias WRITE = 2
alias PROV_BUF = 3

@value
struct ConnInfo:
    var fd: Int32
    var type: UInt16
    var bid: UInt16

    fn __init__(out self, fd: Int32, type: UInt16, bid: UInt16 = 0):
        self.fd = fd
        self.type = type
        self.bid = bid

    fn to_int(self) -> UInt64:
        """Pack ConnInfo into a 64-bit integer for user_data."""
        return UInt64(self.fd) << 32 | UInt64(self.type) << 16 | UInt64(self.bid)
        
    @staticmethod
    fn from_int(value: UInt64) -> Self:
        """Unpack ConnInfo from a 64-bit integer."""
        return Self(
            fd=Int32((value >> 32) & 0xFFFFFFFF),
            type=UInt16((value >> 16) & 0xFFFF),
            bid=UInt16(value & 0xFFFF)
        )


fn main() raises:
    # Initialize io_uring instance
    ring = IoUring[](sq_entries=16)
    
    var buffer_ptr = UnsafePointer[Scalar[DType.int8]].alloc(MAX_MESSAGE_LEN)
    var buffer = Buffer[DType.int8, MAX_MESSAGE_LEN](buffer_ptr)

    # Setup listener socket
    port = 8081
    listener_fd = socket(AddrFamily.INET, SocketType.STREAM)
    bind(listener_fd, SocketAddrV4(0, 0, 0, 0, port=port))
    listen(listener_fd, backlog=BACKLOG)
    print("Echo server listening ", listener_fd.unsafe_fd(), "on port", port)

    # Add initial accept
    var sq = ring.sq()
    if sq:
        conn = ConnInfo(fd=Int32(listener_fd.unsafe_fd()), type=ACCEPT)
        _ = Accept(sq.__next__(), listener_fd).user_data(conn.to_int())

    # Main event loop
    while True:
        # Submit and wait for 1 completion events (cqes)
        submitted = ring.submit_and_wait(wait_nr=1)
        
        # Process completions (cqe)
        for cqe in ring.cq(wait_nr=0):
            res = cqe.res
            user_data = cqe.user_data
            if res < 0:
                print("Error:", res)
                continue
            conn = ConnInfo.from_int(user_data)

            # Handle accept completion
            if conn.type == ACCEPT:
                if res >= 0:
                    client_fd = Fd(unsafe_fd=res)
                    print("New connection:", client_fd.unsafe_fd())

                    # Add read for new connection
                    sq = ring.sq()
                    if sq:
                        read_conn = ConnInfo(fd=client_fd.unsafe_fd(), type=READ)
                        _ = Read[type=SQE64, origin=__origin_of(sq)](sq.__next__(), client_fd, buffer_ptr, MAX_MESSAGE_LEN).user_data(read_conn.to_int())

                # Re-add accept
                sq = ring.sq()
                if sq:
                    accept_conn = ConnInfo(fd=listener_fd.unsafe_fd(), type=ACCEPT)
                    _ = Accept(sq.__next__(), listener_fd).user_data(accept_conn.to_int())

            # Handle read completion
            elif conn.type == READ:
                print("Read completion")
                if res <= 0:
                    print("Connection closed:", conn.fd) 
                else:
                    # Echo data back
                    sq = ring.sq()
                    if sq:
                        write_conn = ConnInfo(fd=conn.fd, type=WRITE)
                        _ = Write[type=SQE64, origin=__origin_of(sq)](sq.__next__(), Fd(unsafe_fd=write_conn.fd), buffer_ptr, len(buffer)).user_data(write_conn.to_int())

                    # Add new read
                    sq = ring.sq()
                    if sq:
                        read_conn = ConnInfo(fd=conn.fd, type=READ)
                        _ = Read[type=SQE64, origin=__origin_of(sq)](sq.__next__(), Fd(unsafe_fd=conn.fd), buffer_ptr, MAX_MESSAGE_LEN).user_data(read_conn.to_int())

