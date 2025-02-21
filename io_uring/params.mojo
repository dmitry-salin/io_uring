from .utils import _next_power_of_two
from mojix.errno import Errno
from mojix.io_uring import IoUringParams, IoUringSetupFlags

alias SQ_ENTRIES_MAX = 32768
alias CQ_ENTRIES_MAX = SQ_ENTRIES_MAX * 2


@value
struct Params(Defaultable):
    var flags: IoUringSetupFlags
    var _cq_entries: UInt32
    var sq_thread_cpu: UInt32
    var sq_thread_idle: UInt32
    var wq_fd: UInt32
    var _dontfork: Bool

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(out self):
        self.flags = IoUringSetupFlags.NO_SQARRAY
        self._cq_entries = 0
        self.sq_thread_cpu = 0
        self.sq_thread_idle = 0
        self.wq_fd = 0
        self._dontfork = False

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    # TODO: Use NonZeroUInt32 value type.
    fn cq_entries(inout self, value: UInt32) -> ref [self] Self:
        self._cq_entries = value
        self.flags |= IoUringSetupFlags.CQSIZE
        return self

    fn clamp(inout self) -> ref [self] Self:
        self.flags |= IoUringSetupFlags.CLAMP
        return self

    fn dontfork(inout self) -> ref [self] Self:
        self._dontfork = True
        return self

    fn is_dontfork(self) -> Bool:
        return self._dontfork


@register_passable("trivial")
struct Entries:
    var sq_entries: UInt32
    var cq_entries: UInt32

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(out self, *, sq_entries: UInt32, params: IoUringParams) raises:
        if sq_entries == 0:
            raise String(Errno.EINVAL)

        self.sq_entries = _next_power_of_two(sq_entries)
        if self.sq_entries > SQ_ENTRIES_MAX:
            if not params.flags & IoUringSetupFlags.CLAMP:
                raise String(Errno.EINVAL)
            self.sq_entries = SQ_ENTRIES_MAX

        if params.flags & IoUringSetupFlags.CQSIZE:
            if params.cq_entries == 0:
                raise String(Errno.EINVAL)
            self.cq_entries = _next_power_of_two(params.cq_entries)
            if self.cq_entries > CQ_ENTRIES_MAX:
                if not params.flags & IoUringSetupFlags.CLAMP:
                    raise String(Errno.EINVAL)
                self.cq_entries = CQ_ENTRIES_MAX
            if self.cq_entries < self.sq_entries:
                raise String(Errno.EINVAL)
        else:
            self.cq_entries = self.sq_entries * 2
