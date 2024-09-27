from .syscalls import _socket, _bind, _listen
from .types import (
    Backlog,
    AddressFamily,
    SocketType,
    SocketFlags,
    Protocol,
    SocketAddress,
    SocketAddressV4,
)
from mojix.fd import OwnedFd, FileDescriptor


@always_inline("nodebug")
fn socket(
    domain: AddressFamily,
    type: SocketType,
) raises -> OwnedFd:
    """Creates a socket.
    [Linux]: https://man7.org/linux/man-pages/man2/socket.2.html.
    """
    return _socket(domain, type, SocketFlags(), Protocol())


@always_inline("nodebug")
fn socket(
    domain: AddressFamily,
    type: SocketType,
    protocol: Protocol,
) raises -> OwnedFd:
    """Creates a socket.
    [Linux]: https://man7.org/linux/man-pages/man2/socket.2.html.
    """
    return _socket(domain, type, SocketFlags(), protocol)


@always_inline("nodebug")
fn socket(
    domain: AddressFamily,
    type: SocketType,
    flags: SocketFlags,
    protocol: Protocol,
) raises -> OwnedFd:
    """Creates a socket.
    [Linux]: https://man7.org/linux/man-pages/man2/socket.2.html.
    """
    return _socket(domain, type, flags, protocol)


@always_inline("nodebug")
fn bind[Fd: FileDescriptor](fd: Fd, ref [_]addr: SocketAddressV4) raises:
    """Binds a socket to an IPV4 address.
    [Linux]: https://man7.org/linux/man-pages/man2/bind.2.html.
    """
    _bind(fd, addr.arg())


@always_inline("nodebug")
fn bind[Fd: FileDescriptor, Addr: SocketAddress](fd: Fd, addr: Addr) raises:
    """Binds a socket to an address.
    [Linux]: https://man7.org/linux/man-pages/man2/bind.2.html.
    """
    _bind(fd, addr)


@always_inline("nodebug")
fn listen[Fd: FileDescriptor](fd: Fd, backlog: Backlog) raises:
    """Enables listening for incoming connections.
    [Linux]: https://man7.org/linux/man-pages/man2/listen.2.html.
    """
    _listen(fd, backlog)
