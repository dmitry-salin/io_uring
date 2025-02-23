import sys
from buffer import Buffer
from collections import InlineArray
from memory import UnsafePointer

from mojix.errno import Errno
from mojix.fd import Fd, OwnedFd, UnsafeFd
from mojix.io_uring import SQE64, IoUringSqeFlags
from mojix.net.socket import socket, bind, listen
from mojix.net.types import AddrFamily, SocketType, SocketAddrV4, SocketFlags
from mojix.timespec import Timespec
from io_uring import IoUring, WaitArg
from io_uring.op import Accept, PrepProvideBuffers, Read, Write, Nop

alias BYTE = Int8
# Do not increase this until we update the Mojo compiler to improve metaprogramming
# See https://github.com/modular/mojo/commit/248de11a021f24ceb9037634b0601deb39cfc142
alias MAX_CONNECTIONS = 8 # 1024  
alias BACKLOG = 512 
alias MAX_MESSAGE_LEN = 2048
alias BUFFERS_COUNT = MAX_CONNECTIONS
alias BUFFERS_SIZE = BUFFERS_COUNT * MAX_MESSAGE_LEN

alias ACCEPT = 0
alias READ = 1
alias WRITE = 2
alias PROV_BUF = 3

alias BufferType = Buffer[DType.int8, MAX_MESSAGE_LEN]

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


struct Buffers[
    T: CollectionElement = BYTE,
    C: Int = BUFFERS_COUNT,
    L: Int = MAX_MESSAGE_LEN,
]:
    var _data: InlineArray[T, C * L]

    fn __init__(out self, fill: T):
        self._data = InlineArray[T, C * L](fill=fill)

    fn __getitem__(self, index: UInt32) -> T:
        return self._data[index]

    fn unsafe_ptr(self, index: Int = 0) -> UnsafePointer[BYTE]:
        initial_ptr = self._data.unsafe_ptr().bitcast[BYTE]()
        return initial_ptr + index * L


fn main() raises:
    args = sys.argv()
    port = Int(args[1]) if len(args) > 1 else 8080
    # Initialize io_uring instance
    ring = IoUring[](sq_entries=16)

    var buffers = Buffers(fill=0)
    var buffers_ptr = buffers.unsafe_ptr()
    
    var buffer_ptr = UnsafePointer[Scalar[DType.int8]].alloc(MAX_MESSAGE_LEN)
    var buffer = Buffer[DType.int8, MAX_MESSAGE_LEN](buffer_ptr)

    # Setup listener socket
    gid = 0
    listener_fd = socket(AddrFamily.INET, SocketType.STREAM)
    bind(listener_fd, SocketAddrV4(0, 0, 0, 0, port=port))
    listen(listener_fd, backlog=BACKLOG)
    print("Echo server listening ", listener_fd.unsafe_fd(), "on port", port)

    # Add initial accept
    var sq = ring.sq()
    if sq:
        # Prep Provide buffers
        _ = PrepProvideBuffers[type=SQE64, origin=__origin_of(sq)](sq.__next__(), buffers_ptr, MAX_MESSAGE_LEN, BUFFERS_COUNT, gid)

    # Submit and wait for buffer registration
    submitted = ring.submit_and_wait(wait_nr=1)
    for cqe in ring.cq(wait_nr=0):
        res = cqe.res
        if res < 0:
            print("Buffer registration failed:", cqe.res)

    # Add the initial accept
    sq = ring.sq()
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
                    print("New connection: fd=", client_fd.unsafe_fd(), "bid=", conn.bid)

                    # Add read for new connection
                    sq = ring.sq()
                    if sq:
                        read_conn = ConnInfo(fd=client_fd.unsafe_fd(), type=READ)
                        _ = Read[type=SQE64, origin=__origin_of(sq)](sq.__next__(), client_fd, buffer_ptr, MAX_MESSAGE_LEN).user_data(read_conn.to_int()).sqe_flags(IoUringSqeFlags.BUFFER_SELECT)

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
                    bid = Int(cqe.flags.value >> 16)
                    bytes_read = Int(res)
                    print("Buffer ID:", bid)
                    print("Bytes read:", bytes_read)
                    # Echo data back
                    sq = ring.sq()
                    if sq:
                        write_conn = ConnInfo(fd=conn.fd, type=WRITE, bid=bid)
                        buff_read = buffers.unsafe_ptr(bid)
                        _ = Write[type=SQE64, origin=__origin_of(sq)](sq.__next__(), Fd(unsafe_fd=write_conn.fd), buff_read, bytes_read).user_data(write_conn.to_int())

                    # Add new read
                    sq = ring.sq()
                    if sq:
                        read_conn = ConnInfo(fd=conn.fd, type=READ)
                        _ = Read[type=SQE64, origin=__origin_of(sq)](sq.__next__(), Fd(unsafe_fd=conn.fd), buffer_ptr, MAX_MESSAGE_LEN).user_data(read_conn.to_int()).sqe_flags(IoUringSqeFlags.BUFFER_SELECT)

            # Handle write completion
            elif conn.type == WRITE:
                print("Write completion in bid:", conn.bid)
                # TODO: Not working yet. Find out why
            #    # Re-add the buffer
            #    buffer_to_add = buffers.unsafe_ptr(Int(conn.bid))
            #    _ = PrepProvideBuffers[type=SQE64, origin=__origin_of(sq)](sq.__next__(), buffer_to_add, MAX_MESSAGE_LEN, 1, gid)
            #    # Add a new read for the connection
            #    _ = Read[type=SQE64, origin=__origin_of(sq)](sq.__next__(), Fd(unsafe_fd=conn.fd), buffer_ptr, MAX_MESSAGE_LEN).user_data(conn.to_int()).sqe_flags(IoUringSqeFlags.BUFFER_SELECT)

