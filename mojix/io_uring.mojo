from .ctypes import c_void
from .fd import UnsafeFd, IoUringOwnedFd, IoUringFd
from .errno import unsafe_decode_result
from .utils import _aligned_u64
from linux_raw.x86_64.io_uring import *
from linux_raw.x86_64.general import (
    __NR_io_uring_setup,
    __NR_io_uring_register,
    __NR_io_uring_enter,
)
from linux_raw.x86_64.syscall import syscall
from linux_raw.utils import DTypeArray
from memory import UnsafePointer


@always_inline
fn io_uring_setup[
    is_registered: Bool
](sq_entries: UInt32, inout params: IoUringParams) raises -> IoUringOwnedFd[
    is_registered
]:
    """Sets up a context for performing asynchronous I/O.
    [Linux]: https://www.man7.org/linux/man-pages/man2/io_uring_setup.2.html.

    Parameters:
        is_registered: Whether the returned file descriptor is registered or not.

    Args:
        sq_entries: The requested number of submission queue entries.
        params: The struct used by the application to pass options to
                the kernel, and by the kernel to convey information about
                the ring buffers.

    Returns:
        The file descriptor which can be used to perform subsequent
        operations on the `io_uring` instance.

    Raises:
        `Errno` if the syscall returned an error.
    """
    params.flags |= IoUringOwnedFd[is_registered].SETUP_FLAGS

    res = syscall[__NR_io_uring_setup, Scalar[DType.index]](
        sq_entries, UnsafePointer.address_of(params)
    )
    return IoUringOwnedFd[is_registered](
        unsafe_fd=unsafe_decode_result[UnsafeFd.element_type](res)
    )


@always_inline
fn io_uring_register(
    fd: IoUringOwnedFd,
    arg: RegisterArg,
) raises -> UInt32:
    """Registers/unregisters files or user buffers for asynchronous I/O.
    [Linux]: https://www.man7.org/linux/man-pages/man2/io_uring_register.2.html.

    Args:
        fd: The file descriptor returned by `io_uring_setup`.
        arg: The resources for registration/deregistration.

    Returns:
        Either 0 or a positive value, depending on the operation code used.

    Raises:
        `Errno` if the syscall returned an error.
    """
    res = syscall[__NR_io_uring_register, Scalar[DType.index]](
        fd.io_uring_fd(),
        arg.opcode.id | fd.REGISTER_FLAGS.value,
        arg.arg_unsafe_ptr,
        arg.nr_args,
    )
    return unsafe_decode_result[DType.uint32](res)


@always_inline
fn io_uring_enter(
    fd: IoUringOwnedFd,
    *,
    to_submit: UInt32,
    min_complete: UInt32,
    flags: IoUringEnterFlags,
    arg: EnterArg,
) raises -> UInt32:
    """Initiates and/or waits for asynchronous I/O to complete.
    [Linux]: https://man7.org/linux/man-pages/man2/io_uring_enter.2.html.

    Args:
        fd: The file descriptor returned by `io_uring_setup`.
        to_submit: The number of I/Os to submit from the submission
                          queue.
        min_complete: The specified number of events to wait for before
                      returning (if `GETEVENTS` flag is set).
        flags: The bitmask of the `IoUringEnterFlags` values.
        arg: The enter argument (wait parameters).

    Returns:
        The number of I/Os successfully consumed. This can be zero
        if `to_submit` was zero or if the submission queue was empty.

    Raises:
        `Errno` if the syscall returned an error.
    """
    res = syscall[__NR_io_uring_enter, Scalar[DType.index]](
        fd.io_uring_fd(),
        to_submit,
        min_complete,
        flags | arg.flags | fd.ENTER_FLAGS,
        arg.arg_unsafe_ptr,
        arg.size,
    )
    return unsafe_decode_result[DType.uint32](res)


@value
struct IoUringParams(Defaultable):
    var sq_entries: UInt32
    var cq_entries: UInt32
    var flags: IoUringSetupFlags
    var sq_thread_cpu: UInt32
    var sq_thread_idle: UInt32
    var features: IoUringFeatureFlags
    var wq_fd: UInt32
    var resv: DTypeArray[DType.uint32, 3]
    var sq_off: io_sqring_offsets
    var cq_off: io_cqring_offsets

    @always_inline("nodebug")
    fn __init__(inout self):
        self.sq_entries = 0
        self.cq_entries = 0
        self.flags = IoUringSetupFlags()
        self.sq_thread_cpu = 0
        self.sq_thread_idle = 0
        self.features = IoUringFeatureFlags()
        self.wq_fd = 0
        self.resv = DTypeArray[DType.uint32, 3]()
        self.sq_off = io_sqring_offsets()
        self.cq_off = io_cqring_offsets()


alias SQE64 = SQE.SQE64
alias SQE128 = SQE.SQE128


@nonmaterializable(NoneType)
@register_passable("trivial")
struct SQE:
    alias SQE64 = Self {
        id: 0,
        size: 64,
        align: 8,
        array_size: 0,
        setup_flags: IoUringSetupFlags(),
    }

    alias SQE128 = Self {
        id: 1,
        size: 128,
        align: 8,
        array_size: 64,
        setup_flags: IoUringSetupFlags.SQE128,
    }

    var id: UInt8
    var size: IntLiteral
    var align: IntLiteral
    var array_size: IntLiteral
    var setup_flags: IoUringSetupFlags

    @always_inline("nodebug")
    fn __is__(self, rhs: Self) -> Bool:
        """Defines whether one SQE has the same identity as another.

        Args:
            rhs: The SQE to compare against.

        Returns:
            True if the SQEs have the same identity, False otherwise.
        """
        return self.id == rhs.id


alias CQE16 = CQE.CQE16
alias CQE32 = CQE.CQE32

alias CQE_SIZE_DEFAULT = CQE16.size
alias CQE_SIZE_MAX = CQE32.size


@nonmaterializable(NoneType)
@register_passable("trivial")
struct CQE:
    alias CQE16 = Self {
        id: 0,
        size: 16,
        align: 8,
        array_size: 0,
        rings_size: 64,
        setup_flags: IoUringSetupFlags(),
    }

    alias CQE32 = Self {
        id: 1,
        size: 32,
        align: 8,
        array_size: 2,
        rings_size: 64 * 2,
        setup_flags: IoUringSetupFlags.CQE32,
    }

    var id: UInt8
    var size: IntLiteral
    var align: IntLiteral
    var array_size: IntLiteral
    var rings_size: IntLiteral
    """For the size of the rings, we perform calculations in the same way as the kernel.
    [Linux]: https://github.com/torvalds/linux/blob/v6.7/io_uring/io_uring.c#L2804.
    [Linux]: https://github.com/torvalds/linux/blob/v6.7/include/linux/io_uring_types.h#L83.
    """
    var setup_flags: IoUringSetupFlags

    @always_inline("nodebug")
    fn __is__(self, rhs: Self) -> Bool:
        """Defines whether one CQE has the same identity as another.

        Args:
            rhs: The CQE to compare against.

        Returns:
            True if the CQEs have the same identity, False otherwise.
        """
        return self.id == rhs.id


@value
struct addr3_struct(Defaultable):
    var addr3: UInt64
    var __pad2: DTypeArray[DType.uint64, 1]

    @always_inline("nodebug")
    fn __init__(inout self):
        self.addr3 = 0
        self.__pad2 = DTypeArray[DType.uint64, 1]()


@value
struct Sqe[type: SQE]:
    """[Linux]: https://github.com/torvalds/linux/blob/v6.7/include/uapi/linux/io_uring.h#L30.
    """

    alias Array = DTypeArray[DType.uint8, type.array_size]

    var opcode: IoUringOp
    var flags: IoUringSqeFlags
    var ioprio: UInt16
    var fd: UnsafeFd
    var off_or_addr2_or_cmd_op: UInt64
    var addr_or_splice_off_in_or_msgring_cmd: UInt64
    var len_or_poll_flags: UInt32
    var op_flags: UInt32
    var user_data: UInt64
    var buf_index_or_buf_group: UInt16
    var personality: UInt16
    var splice_fd_in_or_file_index_or_optlen_or_addr_len: UInt32
    var addr3_or_optval_or_cmd: addr3_struct
    var _big_sqe: Self.Array

    @always_inline("nodebug")
    fn cmd(
        inout self: Sqe[SQE128],
    ) -> ref [__lifetime_of(self)] DTypeArray[DType.uint8, 80]:
        return UnsafePointer.address_of(self.addr3_or_optval_or_cmd).bitcast[
            DTypeArray[DType.uint8, 80]
        ]()[]


@value
struct Cqe[type: CQE]:
    """[Linux]: https://github.com/torvalds/linux/blob/v6.7/include/uapi/linux/io_uring.h#L392.
    """

    var user_data: UInt64
    var res: Int32
    var flags: IoUringCqeFlags
    var _big_cqe: DTypeArray[DType.uint64, type.array_size]

    @always_inline("nodebug")
    fn cmd(
        self: Cqe[CQE32],
    ) -> ref [__lifetime_of(self._big_cqe)] DTypeArray[
        DType.uint64, CQE32.array_size
    ]:
        return self._big_cqe


@value
@register_passable("trivial")
struct IoUringSetupFlags(Defaultable, Boolable):
    alias IOPOLL = Self(IORING_SETUP_IOPOLL)
    alias SQPOLL = Self(IORING_SETUP_SQPOLL)
    alias SQ_AFF = Self(IORING_SETUP_SQ_AFF)
    alias CQSIZE = Self(IORING_SETUP_CQSIZE)
    alias CLAMP = Self(IORING_SETUP_CLAMP)
    alias ATTACH_WQ = Self(IORING_SETUP_ATTACH_WQ)
    alias R_DISABLED = Self(IORING_SETUP_R_DISABLED)
    alias SUBMIT_ALL = Self(IORING_SETUP_SUBMIT_ALL)
    alias COOP_TASKRUN = Self(IORING_SETUP_COOP_TASKRUN)
    alias TASKRUN_FLAG = Self(IORING_SETUP_TASKRUN_FLAG)
    alias SQE128 = Self(IORING_SETUP_SQE128)
    alias CQE32 = Self(IORING_SETUP_CQE32)
    alias SINGLE_ISSUER = Self(IORING_SETUP_SINGLE_ISSUER)
    alias DEFER_TASKRUN = Self(IORING_SETUP_DEFER_TASKRUN)
    alias NO_MMAP = Self(IORING_SETUP_NO_MMAP)
    alias REGISTERED_FD_ONLY = Self(IORING_SETUP_REGISTERED_FD_ONLY)
    alias NO_SQARRAY = Self(IORING_SETUP_NO_SQARRAY)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0

    @always_inline("nodebug")
    fn __or__(self, rhs: Self) -> Self:
        """Returns `self | rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self | rhs`.
        """
        return self.value | rhs.value

    @always_inline("nodebug")
    fn __ior__(inout self, rhs: Self):
        """Computes `self | rhs` and saves the result in self.

        Args:
            rhs: The RHS value.
        """
        self = self | rhs

    @always_inline("nodebug")
    fn __and__(self, rhs: Self) -> Self:
        """Returns `self & rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self & rhs`.
        """
        return self.value & rhs.value

    @always_inline("nodebug")
    fn __bool__(self) -> Bool:
        """Converts this flags to Bool.

        Returns:
            False Bool value if the value is equal to 0 and True otherwise.
        """
        return self.value != 0


@value
@register_passable("trivial")
struct IoUringFeatureFlags(Defaultable, Boolable):
    alias SINGLE_MMAP = Self(IORING_FEAT_SINGLE_MMAP)
    alias NODROP = Self(IORING_FEAT_NODROP)
    alias SUBMIT_STABLE = Self(IORING_FEAT_SUBMIT_STABLE)
    alias RW_CUR_POS = Self(IORING_FEAT_RW_CUR_POS)
    alias CUR_PERSONALITY = Self(IORING_FEAT_CUR_PERSONALITY)
    alias FAST_POLL = Self(IORING_FEAT_FAST_POLL)
    alias POLL_32BITS = Self(IORING_FEAT_POLL_32BITS)
    alias SQPOLL_NONFIXED = Self(IORING_FEAT_SQPOLL_NONFIXED)
    alias EXT_ARG = Self(IORING_FEAT_EXT_ARG)
    alias NATIVE_WORKERS = Self(IORING_FEAT_NATIVE_WORKERS)
    alias RSRC_TAGS = Self(IORING_FEAT_RSRC_TAGS)
    alias CQE_SKIP = Self(IORING_FEAT_CQE_SKIP)
    alias LINKED_FILE = Self(IORING_FEAT_LINKED_FILE)
    alias REG_REG_RING = Self(IORING_FEAT_REG_REG_RING)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0

    @always_inline("nodebug")
    fn __and__(self, rhs: Self) -> Self:
        """Returns `self & rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self & rhs`.
        """
        return self.value & rhs.value

    @always_inline("nodebug")
    fn __bool__(self) -> Bool:
        """Converts this flags to Bool.

        Returns:
            False Bool value if the value is equal to 0 and True otherwise.
        """
        return self.value != 0


@register_passable("trivial")
struct IoUringRegisterOp:
    alias REGISTER_BUFFERS = Self {id: IORING_REGISTER_BUFFERS}
    alias UNREGISTER_BUFFERS = Self {id: IORING_UNREGISTER_BUFFERS}
    alias REGISTER_FILES = Self {id: IORING_REGISTER_FILES}
    alias UNREGISTER_FILES = Self {id: IORING_UNREGISTER_FILES}
    alias REGISTER_EVENTFD = Self {id: IORING_REGISTER_EVENTFD}
    alias UNREGISTER_EVENTFD = Self {id: IORING_UNREGISTER_EVENTFD}
    alias REGISTER_FILES_UPDATE = Self {id: IORING_REGISTER_FILES_UPDATE}
    alias REGISTER_EVENTFD_ASYNC = Self {id: IORING_REGISTER_EVENTFD_ASYNC}
    alias REGISTER_PROBE = Self {id: IORING_REGISTER_PROBE}
    alias REGISTER_PERSONALITY = Self {id: IORING_REGISTER_PERSONALITY}
    alias UNREGISTER_PERSONALITY = Self {id: IORING_UNREGISTER_PERSONALITY}
    alias REGISTER_RESTRICTIONS = Self {id: IORING_REGISTER_RESTRICTIONS}
    alias REGISTER_ENABLE_RINGS = Self {id: IORING_REGISTER_ENABLE_RINGS}
    alias REGISTER_FILES2 = Self {id: IORING_REGISTER_FILES2}
    alias REGISTER_FILES_UPDATE2 = Self {id: IORING_REGISTER_FILES_UPDATE2}
    alias REGISTER_BUFFERS2 = Self {id: IORING_REGISTER_BUFFERS2}
    alias REGISTER_BUFFERS_UPDATE = Self {id: IORING_REGISTER_BUFFERS_UPDATE}
    alias REGISTER_IOWQ_AFF = Self {id: IORING_REGISTER_IOWQ_AFF}
    alias UNREGISTER_IOWQ_AFF = Self {id: IORING_UNREGISTER_IOWQ_AFF}
    alias REGISTER_IOWQ_MAX_WORKERS = Self {
        id: IORING_REGISTER_IOWQ_MAX_WORKERS
    }
    alias REGISTER_RING_FDS = Self {id: IORING_REGISTER_RING_FDS}
    alias UNREGISTER_RING_FDS = Self {id: IORING_UNREGISTER_RING_FDS}
    alias REGISTER_PBUF_RING = Self {id: IORING_REGISTER_PBUF_RING}
    alias UNREGISTER_PBUF_RING = Self {id: IORING_UNREGISTER_PBUF_RING}
    alias REGISTER_SYNC_CANCEL = Self {id: IORING_REGISTER_SYNC_CANCEL}
    alias REGISTER_FILE_ALLOC_RANGE = Self {
        id: IORING_REGISTER_FILE_ALLOC_RANGE
    }

    var id: UInt32


@value
@register_passable("trivial")
struct IoUringRegisterFlags(Defaultable):
    alias REGISTER_USE_REGISTERED_RING = Self(
        IORING_REGISTER_USE_REGISTERED_RING
    )

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


@value
@register_passable("trivial")
struct IoUringSqFlags(Defaultable):
    alias NEED_WAKEUP = UInt32(IORING_SQ_NEED_WAKEUP)
    alias CQ_OVERFLOW = UInt32(IORING_SQ_CQ_OVERFLOW)
    alias TASKRUN = UInt32(IORING_SQ_TASKRUN)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


@value
@register_passable("trivial")
struct IoUringEnterFlags(Defaultable):
    alias GETEVENTS = Self(IORING_ENTER_GETEVENTS)
    alias SQ_WAKEUP = Self(IORING_ENTER_SQ_WAKEUP)
    alias SQ_WAIT = Self(IORING_ENTER_SQ_WAIT)
    alias EXT_ARG = Self(IORING_ENTER_EXT_ARG)
    alias REGISTERED_RING = Self(IORING_ENTER_REGISTERED_RING)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0

    @always_inline("nodebug")
    fn __or__(self, rhs: Self) -> Self:
        """Returns `self | rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self | rhs`.
        """
        return self.value | rhs.value

    @always_inline("nodebug")
    fn __ior__(inout self, rhs: Self):
        """Computes `self | rhs` and saves the result in self.

        Args:
            rhs: The RHS value.
        """
        self = self | rhs


@value
@register_passable("trivial")
struct IoUringSqeFlags(Defaultable):
    alias FIXED_FILE = Self(1 << IOSQE_FIXED_FILE_BIT)
    alias IO_DRAIN = Self(1 << IOSQE_IO_DRAIN_BIT)
    alias IO_LINK = Self(1 << IOSQE_IO_LINK_BIT)
    alias IO_HARDLINK = Self(1 << IOSQE_IO_HARDLINK_BIT)
    alias ASYNC = Self(1 << IOSQE_ASYNC_BIT)
    alias BUFFER_SELECT = Self(1 << IOSQE_BUFFER_SELECT_BIT)
    alias CQE_SKIP_SUCCESS = Self(1 << IOSQE_CQE_SKIP_SUCCESS_BIT)

    var value: UInt8

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0

    @always_inline("nodebug")
    fn __or__(self, rhs: Self) -> Self:
        """Returns `self | rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self | rhs`.
        """
        return self.value | rhs.value

    @always_inline("nodebug")
    fn __ior__(inout self, rhs: Self):
        """Computes `self | rhs` and saves the result in self.

        Args:
            rhs: The RHS value.
        """
        self = self | rhs


@value
@register_passable("trivial")
struct IoUringCqeFlags(Defaultable, Boolable):
    alias BUFFER = Self(IORING_CQE_F_BUFFER)
    alias MORE = Self(IORING_CQE_F_MORE)
    alias SOCK_NONEMPTY = Self(IORING_CQE_F_SOCK_NONEMPTY)
    alias NOTIF = Self(IORING_CQE_F_NOTIF)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0

    @always_inline("nodebug")
    fn __and__(self, rhs: Self) -> Self:
        """Returns `self & rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self & rhs`.
        """
        return self.value & rhs.value

    @always_inline("nodebug")
    fn __bool__(self) -> Bool:
        """Converts this flags to Bool.

        Returns:
            False Bool value if the value is equal to 0 and True otherwise.
        """
        return self.value != 0


@register_passable("trivial")
struct IoUringOp:
    alias NOP = Self {id: IORING_OP_NOP}
    alias READV = Self {id: IORING_OP_READV}
    alias WRITEV = Self {id: IORING_OP_WRITEV}
    alias FSYNC = Self {id: IORING_OP_FSYNC}
    alias READ_FIXED = Self {id: IORING_OP_READ_FIXED}
    alias WRITE_FIXED = Self {id: IORING_OP_WRITE_FIXED}
    alias POLL_ADD = Self {id: IORING_OP_POLL_ADD}
    alias POLL_REMOVE = Self {id: IORING_OP_POLL_REMOVE}
    alias SYNC_FILE_RANGE = Self {id: IORING_OP_SYNC_FILE_RANGE}
    alias SENDMSG = Self {id: IORING_OP_SENDMSG}
    alias RECVMSG = Self {id: IORING_OP_RECVMSG}
    alias TIMEOUT = Self {id: IORING_OP_TIMEOUT}
    alias TIMEOUT_REMOVE = Self {id: IORING_OP_TIMEOUT_REMOVE}
    alias ACCEPT = Self {id: IORING_OP_ACCEPT}
    alias ASYNC_CANCEL = Self {id: IORING_OP_ASYNC_CANCEL}
    alias LINK_TIMEOUT = Self {id: IORING_OP_LINK_TIMEOUT}
    alias CONNECT = Self {id: IORING_OP_CONNECT}
    alias FALLOCATE = Self {id: IORING_OP_FALLOCATE}
    alias OPENAT = Self {id: IORING_OP_OPENAT}
    alias CLOSE = Self {id: IORING_OP_CLOSE}
    alias FILES_UPDATE = Self {id: IORING_OP_FILES_UPDATE}
    alias STATX = Self {id: IORING_OP_STATX}
    alias READ = Self {id: IORING_OP_READ}
    alias WRITE = Self {id: IORING_OP_WRITE}
    alias FADVISE = Self {id: IORING_OP_FADVISE}
    alias MADVISE = Self {id: IORING_OP_MADVISE}
    alias SEND = Self {id: IORING_OP_SEND}
    alias RECV = Self {id: IORING_OP_RECV}
    alias OPENAT2 = Self {id: IORING_OP_OPENAT2}
    alias EPOLL_CTL = Self {id: IORING_OP_EPOLL_CTL}
    alias SPLICE = Self {id: IORING_OP_SPLICE}
    alias PROVIDE_BUFFERS = Self {id: IORING_OP_PROVIDE_BUFFERS}
    alias REMOVE_BUFFERS = Self {id: IORING_OP_REMOVE_BUFFERS}
    alias TEE = Self {id: IORING_OP_TEE}
    alias SHUTDOWN = Self {id: IORING_OP_SHUTDOWN}
    alias RENAMEAT = Self {id: IORING_OP_RENAMEAT}
    alias UNLINKAT = Self {id: IORING_OP_UNLINKAT}
    alias MKDIRAT = Self {id: IORING_OP_MKDIRAT}
    alias SYMLINKAT = Self {id: IORING_OP_SYMLINKAT}
    alias LINKAT = Self {id: IORING_OP_LINKAT}
    alias MSG_RING = Self {id: IORING_OP_MSG_RING}
    alias FSETXATTR = Self {id: IORING_OP_FSETXATTR}
    alias SETXATTR = Self {id: IORING_OP_SETXATTR}
    alias FGETXATTR = Self {id: IORING_OP_FGETXATTR}
    alias GETXATTR = Self {id: IORING_OP_GETXATTR}
    alias SOCKET = Self {id: IORING_OP_SOCKET}
    alias URING_CMD = Self {id: IORING_OP_URING_CMD}
    alias SEND_ZC = Self {id: IORING_OP_SEND_ZC}
    alias SENDMSG_ZC = Self {id: IORING_OP_SENDMSG_ZC}

    var id: UInt8


@value
@register_passable("trivial")
struct IoUringFsyncFlags(Defaultable):
    alias DATASYNC = Self(IORING_FSYNC_DATASYNC)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


@register_passable("trivial")
struct IoUringMsgRingCmds:
    alias DATA = Self {id: IORING_MSG_DATA}
    alias SEND_FD = Self {id: IORING_MSG_SEND_FD}

    var id: UInt64


@value
@register_passable("trivial")
struct IoUringPollFlags(Defaultable):
    alias ADD_MULTI = Self(IORING_POLL_ADD_MULTI)
    alias UPDATE_EVENTS = Self(IORING_POLL_UPDATE_EVENTS)
    alias UPDATE_USER_DATA = Self(IORING_POLL_UPDATE_USER_DATA)
    alias ADD_LEVEL = Self(IORING_POLL_ADD_LEVEL)

    var value: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


@value
@register_passable("trivial")
struct IoUringSendFlags(Defaultable):
    alias POLL_FIRST = Self(IORING_RECVSEND_POLL_FIRST)
    alias FIXED_BUF = Self(IORING_RECVSEND_FIXED_BUF)
    alias ZC_REPORT_USAGE = Self(IORING_SEND_ZC_REPORT_USAGE)

    var value: UInt16

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


@value
@register_passable("trivial")
struct IoUringRecvFlags(Defaultable):
    alias POLL_FIRST = Self(IORING_RECVSEND_POLL_FIRST)
    alias MULTISHOT = Self(IORING_RECV_MULTISHOT)
    alias FIXED_BUF = Self(IORING_RECVSEND_FIXED_BUF)

    var value: UInt16

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


@value
@register_passable("trivial")
struct IoUringAcceptFlags(Defaultable):
    alias MULTISHOT = Self(IORING_ACCEPT_MULTISHOT)

    var value: UInt16

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0


trait AsRegisterArg:
    fn as_register_arg[
        lifetime: MutableLifetime
    ](ref [lifetime]self, *, unsafe_opcode: IoUringRegisterOp) -> RegisterArg[
        lifetime
    ]:
        ...


@register_passable("trivial")
struct RegisterArg[lifetime: MutableLifetime]:
    var opcode: IoUringRegisterOp
    """The operation code."""
    var arg_unsafe_ptr: UnsafePointer[c_void]
    """The pointer to resources for registration/deregistration."""
    var nr_args: UInt32
    """The number of resources for registration/deregistration."""

    @always_inline("nodebug")
    fn __init__(
        inout self,
        *,
        opcode: IoUringRegisterOp,
        arg_unsafe_ptr: UnsafePointer[c_void],
        nr_args: UInt32,
    ):
        self.opcode = opcode
        self.arg_unsafe_ptr = arg_unsafe_ptr
        self.nr_args = nr_args


struct NoRegisterArg:
    alias ENABLE_RINGS = RegisterArg[MutableStaticLifetime](
        opcode=IoUringRegisterOp.REGISTER_ENABLE_RINGS,
        arg_unsafe_ptr=UnsafePointer[c_void](),
        nr_args=0,
    )


@value
@register_passable("trivial")
struct IoUringRsrcUpdate(AsRegisterArg, Defaultable):
    var offset: UInt32
    var resv: UInt32
    var data: UInt64

    @always_inline("nodebug")
    fn __init__(inout self):
        self.offset = 0
        self.resv = 0
        self.data = 0

    @always_inline("nodebug")
    fn as_register_arg[
        lifetime: MutableLifetime
    ](ref [lifetime]self, *, unsafe_opcode: IoUringRegisterOp) -> RegisterArg[
        lifetime
    ]:
        _aligned_u64[Self]()
        return RegisterArg[lifetime](
            opcode=unsafe_opcode,
            arg_unsafe_ptr=UnsafePointer.address_of(self).bitcast[c_void](),
            nr_args=1,
        )


@register_passable("trivial")
struct EnterArg[
    size: UInt, flags: IoUringEnterFlags, lifetime: ImmutableLifetime
]:
    """
    Parameters:
        size: The size of the enter argument.
        flags: The bitmask of the `IoUringEnterFlags` values.
        lifetime: The lifetime of the enter argument.
    """

    var arg_unsafe_ptr: UnsafePointer[c_void]

    @always_inline("nodebug")
    fn __init__(inout self, *, arg_unsafe_ptr: UnsafePointer[c_void]):
        self.arg_unsafe_ptr = arg_unsafe_ptr


alias NO_ENTER_ARG = EnterArg[0, IoUringEnterFlags(), ImmutableStaticLifetime](
    arg_unsafe_ptr=UnsafePointer[c_void]()
)


@value
struct IoUringGetEventsArg(Defaultable):
    var sigmask: UInt64
    var sigmask_sz: UInt32
    var pad: UInt32
    var ts: UInt64

    @always_inline("nodebug")
    fn __init__(inout self):
        self.sigmask = 0
        self.sigmask_sz = 0
        self.pad = 0
        self.ts = 0
