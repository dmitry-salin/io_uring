from .types import (
    Backlog,
    AddressFamily,
    SocketType,
    SocketFlags,
    Protocol,
    SocketAddress,
)
from mojix.ctypes import c_int
from mojix.utils import _size_eq
from mojix.fd import UnsafeFd, OwnedFd, FileDescriptor
from mojix.errno import unsafe_decode_result, unsafe_decode_none
from linux_raw.utils import is_x86_64
from linux_raw.x86_64.general import __NR_socket, __NR_bind, __NR_listen
from linux_raw.x86_64.syscall import syscall


@always_inline
fn _socket(
    domain: AddressFamily,
    type: SocketType,
    flags: SocketFlags,
    protocol: Protocol,
) raises -> OwnedFd:
    constrained[is_x86_64()]()
    _size_eq[SocketType, c_int]()
    _size_eq[SocketFlags, c_int]()
    _size_eq[Protocol, c_int]()

    res = syscall[__NR_socket, Scalar[DType.index], uses_memory=False](
        domain.id.cast[DType.uint32](), type.id | flags.value, protocol
    )
    return OwnedFd(unsafe_fd=unsafe_decode_result[UnsafeFd.element_type](res))


@always_inline
fn _bind[Fd: FileDescriptor, Addr: SocketAddress](fd: Fd, addr: Addr) raises:
    constrained[is_x86_64()]()

    res = syscall[__NR_bind, Scalar[DType.index], uses_memory=False](
        fd.unsafe_fd(), addr.addr_unsafe_ptr(), addr.addr_len()
    )
    unsafe_decode_none(res)


@always_inline
fn _listen[Fd: FileDescriptor](fd: Fd, backlog: Backlog) raises:
    constrained[is_x86_64()]()
    _size_eq[Backlog, c_int]()

    res = syscall[__NR_listen, Scalar[DType.index], uses_memory=False](
        fd.unsafe_fd(), backlog
    )
    unsafe_decode_none(res)
