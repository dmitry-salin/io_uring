from mojix.ctypes import c_void
from mojix.net.types import (
    SocketAddr,
    SocketAddrMut,
    SocketAddrV4,
    RecvFlags,
    SendFlags,
    SocketFlags,
)
from mojix.io import ReadWriteFlags
from mojix.io_uring import (
    Sqe,
    SQE,
    SQE128,
    addr3_struct,
    IoUringOp,
    IoUringSqeFlags,
    IoUringSendFlags,
)
from mojix.fd import NoFd, Fd, IoUringFileDescriptor
from mojix.utils import _size_eq
from memory import UnsafePointer


@always_inline
fn _nop_data[
    type: SQE, origin: MutableOrigin
](ref [origin]sqe: Sqe[type]) -> ref [origin] Sqe[type]:
    sqe.opcode = IoUringOp.NOP
    sqe.flags = IoUringSqeFlags.CQE_SKIP_SUCCESS
    return sqe


@always_inline
fn _prep_rw[
    Fd: IoUringFileDescriptor
](mut sqe: Sqe, op: IoUringOp, fd: Fd, addr: UInt64, len: UInt32):
    sqe.opcode = op
    sqe.flags = Fd.SQE_FLAGS
    sqe.ioprio = 0
    sqe.fd = fd.unsafe_fd()
    sqe.off_or_addr2_or_cmd_op = 0
    sqe.addr_or_splice_off_in_or_msgring_cmd = addr
    sqe.len_or_poll_flags = len
    sqe.op_flags = 0
    sqe.user_data = 0
    sqe.buf_index_or_buf_group = 0
    sqe.personality = 0
    sqe.splice_fd_in_or_file_index_or_optlen_or_addr_len = 0
    sqe.addr3_or_optval_or_cmd = addr3_struct()

    @parameter
    if sqe.type is SQE128:
        sqe._big_sqe = sqe.Array(0)


@always_inline
fn _prep_addr[
    Fd: IoUringFileDescriptor
](mut sqe: Sqe, op: IoUringOp, fd: Fd, addr: UInt64, addr_len: UInt64):
    sqe.opcode = op
    sqe.flags = Fd.SQE_FLAGS
    sqe.ioprio = 0
    sqe.fd = fd.unsafe_fd()
    sqe.off_or_addr2_or_cmd_op = addr_len
    sqe.addr_or_splice_off_in_or_msgring_cmd = addr
    sqe.len_or_poll_flags = 0
    sqe.op_flags = 0
    sqe.user_data = 0
    sqe.buf_index_or_buf_group = 0
    sqe.personality = 0
    sqe.splice_fd_in_or_file_index_or_optlen_or_addr_len = 0
    sqe.addr3_or_optval_or_cmd = addr3_struct()

    @parameter
    if sqe.type is SQE128:
        sqe._big_sqe = sqe.Array(0)


trait SqeAttrs:
    fn user_data(owned self, value: UInt64) -> Self:
        ...

    fn personality(owned self, value: UInt16) -> Self:
        ...

    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        ...


trait Operation(SqeAttrs, Movable):
    ...


@register_passable
struct Accept[type: SQE, origin: MutableOrigin](Operation):
    """Accept a new connection on a socket, equivalent to `accept4(2)`."""

    alias SINCE = 5.5

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor
    ](out self, ref [origin]sqe: Sqe[type], fd: Fd):
        self = Self(sqe, fd, UnsafePointer[c_void](), UnsafePointer[c_void]())

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
        Addr: SocketAddrMut,
    ](out self, ref [origin]sqe: Sqe[type], fd: Fd, ref unsafe_addr: Addr):
        self = Self(
            sqe,
            fd,
            unsafe_addr.addr_unsafe_ptr(),
            unsafe_addr.len_unsafe_ptr(),
        )

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
    ](
        out self,
        ref [origin]sqe: Sqe[type],
        fd: Fd,
        addr_unsafe_ptr: UnsafePointer[c_void],
        addr_len_unsafe_ptr: UnsafePointer[c_void],
    ):
        _prep_addr(
            sqe,
            IoUringOp.ACCEPT,
            fd,
            Int(addr_unsafe_ptr),
            Int(addr_len_unsafe_ptr),
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^

    @always_inline("nodebug")
    fn socket_flags(owned self, flags: SocketFlags) -> Self:
        _size_eq[__type_of(flags), UInt32]()
        self.sqe[].op_flags = flags.value
        return self^


@register_passable
struct Connect[type: SQE, origin: MutableOrigin](Operation):
    """Connect a socket, equivalent to `connect(2)`."""

    alias SINCE = 5.5

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor, Addr: SocketAddr
    ](out self, ref [origin]sqe: Sqe[type], fd: Fd, *, ref unsafe_addr: Addr):
        _prep_addr(
            sqe,
            IoUringOp.CONNECT,
            fd,
            Int(unsafe_addr.addr_unsafe_ptr()),
            Addr.ADDR_LEN.cast[DType.uint64](),
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^


@register_passable
struct Nop[type: SQE, origin: MutableOrigin](Operation):
    """Do not perform any I/O.
    A no-op is more useful than may appear at first glance.
    For example, you could set `IOSQE_IO_DRAIN_BIT` using `sqe_flags()`,
    to use the no-op to know when the ring is idle before acting
    on a kill signal. Also this is useful for testing the performance
    of the `io_uring` implementation itself.
    """

    alias SINCE = 5.1

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__(out self, ref [origin]sqe: Sqe[type]):
        _prep_rw(
            sqe,
            IoUringOp.NOP,
            Fd(unsafe_fd=NoFd),
            0,
            0,
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^


@register_passable
struct Read[type: SQE, origin: MutableOrigin](Operation):
    """Read, equivalent to `pread(2)`."""

    alias SINCE = 5.6

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
    ](
        out self,
        ref [origin]sqe: Sqe[type],
        fd: Fd,
        unsafe_ptr: UnsafePointer[c_void],
        len: UInt,
    ):
        _prep_rw(
            sqe,
            IoUringOp.READ,
            fd,
            Int(unsafe_ptr),
            len,
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^

    @always_inline("nodebug")
    fn ioprio(owned self, value: UInt16) -> Self:
        self.sqe[].ioprio = value
        return self^

    @always_inline("nodebug")
    fn offset(owned self, value: UInt64) -> Self:
        self.sqe[].off_or_addr2_or_cmd_op = value
        return self^

    @always_inline("nodebug")
    fn rw_flags(owned self, flags: ReadWriteFlags) -> Self:
        _size_eq[__type_of(flags), UInt32]()
        self.sqe[].op_flags = flags.value
        return self^

    @always_inline("nodebug")
    fn buf_group(owned self, value: UInt16) -> Self:
        self.sqe[].buf_index_or_buf_group = value
        return self^


@register_passable
struct Recv[type: SQE, origin: MutableOrigin](Operation):
    """Receive a message from a socket, equivalent to `recv(2)`."""

    alias SINCE = 5.6

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
    ](
        out self,
        ref [origin]sqe: Sqe[type],
        fd: Fd,
        unsafe_ptr: UnsafePointer[c_void],
        len: UInt,
    ):
        _prep_rw(
            sqe,
            IoUringOp.RECV,
            fd,
            Int(unsafe_ptr),
            len,
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^

    @always_inline("nodebug")
    fn recv_flags(owned self, flags: RecvFlags) -> Self:
        _size_eq[__type_of(flags), UInt32]()
        self.sqe[].op_flags = flags.value
        return self^

    @always_inline("nodebug")
    fn buf_group(owned self, value: UInt16) -> Self:
        self.sqe[].buf_index_or_buf_group = value
        return self^


@register_passable
struct Send[type: SQE, origin: MutableOrigin](Operation):
    """Send a message on a socket, equivalent to `send(2)`."""

    alias SINCE = 5.6

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
    ](
        out self,
        ref [origin]sqe: Sqe[type],
        fd: Fd,
        unsafe_ptr: UnsafePointer[c_void],
        len: UInt,
    ):
        _prep_rw(
            sqe,
            IoUringOp.SEND,
            fd,
            Int(unsafe_ptr),
            len,
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^

    @always_inline("nodebug")
    fn send_flags(owned self, flags: SendFlags) -> Self:
        _size_eq[__type_of(flags), UInt32]()
        self.sqe[].op_flags = flags.value
        return self^


@register_passable
struct SendZc[type: SQE, origin: MutableOrigin](Operation):
    """Send a zerocopy message on a socket, equivalent to `send(2)`."""

    alias SINCE = 6.0

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
    ](
        out self,
        ref [origin]sqe: Sqe[type],
        fd: Fd,
        unsafe_ptr: UnsafePointer[c_void],
        len: UInt,
    ):
        _prep_rw(
            sqe,
            IoUringOp.SEND_ZC,
            fd,
            Int(unsafe_ptr),
            len,
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^

    @always_inline("nodebug")
    fn send_flags(owned self, flags: SendFlags) -> Self:
        _size_eq[__type_of(flags), UInt32]()
        self.sqe[].op_flags = flags.value
        return self^

    @always_inline("nodebug")
    fn buf_index(owned self, value: UInt16) -> Self:
        self.sqe[].buf_index_or_buf_group = value
        return self^

    @always_inline("nodebug")
    fn send_flags(owned self, flags: IoUringSendFlags) -> Self:
        _size_eq[__type_of(flags), UInt16]()
        self.sqe[].ioprio = flags.value
        return self^


@register_passable
struct Write[type: SQE, origin: MutableOrigin](Operation):
    """Write, equivalent to `pwrite(2)`."""

    alias SINCE = 5.6

    var sqe: Pointer[Sqe[type], origin]

    @always_inline
    fn __init__[
        Fd: IoUringFileDescriptor,
    ](
        out self,
        ref [origin]sqe: Sqe[type],
        fd: Fd,
        unsafe_ptr: UnsafePointer[c_void],
        len: UInt,
    ):
        _prep_rw(
            sqe,
            IoUringOp.WRITE,
            fd,
            Int(unsafe_ptr),
            len,
        )
        self.sqe = Pointer.address_of(sqe)

    @always_inline("nodebug")
    fn user_data(owned self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(owned self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(owned self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^

    @always_inline("nodebug")
    fn ioprio(owned self, value: UInt16) -> Self:
        self.sqe[].ioprio = value
        return self^

    @always_inline("nodebug")
    fn offset(owned self, value: UInt64) -> Self:
        self.sqe[].off_or_addr2_or_cmd_op = value
        return self^

    @always_inline("nodebug")
    fn rw_flags(owned self, flags: ReadWriteFlags) -> Self:
        _size_eq[__type_of(flags), UInt32]()
        self.sqe[].op_flags = flags.value
        return self^
