from .cq import Cq, CqRef
from .sq import Sq, SqRef
from .modes import PollingMode, NOPOLL, IOPOLL, SQPOLL
from .mm import MemoryMapping, Region
from .params import Params
from mojix.ctypes import c_void
from mojix.fd import IoUringOwnedFd
from mojix.io_uring import (
    Sqe,
    SQE,
    SQE64,
    Cqe,
    CQE,
    CQE16,
    IoUringParams,
    IoUringSetupFlags,
    IoUringFeatureFlags,
    IoUringSqFlags,
    IoUringEnterFlags,
    io_sqring_offsets,
    io_cqring_offsets,
    io_uring_setup,
    io_uring_register,
    io_uring_enter,
    IORING_OFF_SQ_RING,
    IORING_OFF_SQES,
    RegisterArg,
    EnterArg,
    NO_ENTER_ARG,
)


struct IoUring[
    sqe: SQE = SQE64,
    cqe: CQE = CQE16,
    polling: PollingMode = NOPOLL,
    *,
    is_registered: Bool = True,
](Movable):
    var _sq: Sq[sqe, polling]
    var _cq: Cq[cqe]
    var fd: IoUringOwnedFd[is_registered]
    var mem: MemoryMapping[sqe, cqe]

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(inout self, *, sq_entries: UInt32) raises:
        self.__init__(sq_entries=sq_entries, params=Params())

    fn __init__(inout self, *, sq_entries: UInt32, params: Params) raises:
        var io_uring_params = IoUringParams(
            0,
            params._cq_entries,
            params.flags,
            params.sq_thread_cpu,
            params.sq_thread_idle,
            IoUringFeatureFlags(),
            params.wq_fd,
            InlineArray[UInt32, 3](0),
            io_sqring_offsets(),
            io_cqring_offsets(),
        )
        self.__init__(sq_entries=sq_entries, params=io_uring_params)
        if params.is_dontfork():
            self.mem.dontfork()

    fn __init__(
        inout self, *, sq_entries: UInt32, inout params: IoUringParams
    ) raises:
        constrained[
            polling is not SQPOLL,
            "SQPOLL mode is disabled because Mojo does not have atomic fence",
        ]()
        alias flags = sqe.setup_flags | cqe.setup_flags | polling.setup_flags
        params.flags |= flags

        @parameter
        if is_registered:
            self.mem = MemoryMapping[sqe, cqe](sq_entries, params)
            self.fd = io_uring_setup[is_registered](sq_entries, params)
        else:
            var fd = io_uring_setup[is_registered](sq_entries, params)
            if not params.features & IoUringFeatureFlags.SINGLE_MMAP:
                raise "system outdated"
            var sq_len = params.sq_off.array + params.sq_entries * sizeof[
                UInt32
            ]()
            var cq_len = params.cq_off.cqes + params.cq_entries * cqe.size
            var sq_cq_mem = Region(
                fd=fd,
                offset=IORING_OFF_SQ_RING,
                len=UInt(max(sq_len, cq_len).cast[DType.index]().value),
            )
            var sqes_mem = Region(
                fd=fd,
                offset=IORING_OFF_SQES,
                len=UInt(
                    (params.sq_entries * sqe.size).cast[DType.index]().value
                ),
            )
            self.fd = fd^
            self.mem = MemoryMapping[sqe, cqe](
                sqes_mem=sqes_mem^, sq_cq_mem=sq_cq_mem^
            )

        self._sq = Sq[sqe, polling](
            params,
            sq_cq_mem=self.mem.sq_cq_mem,
            sqes_mem=self.mem.sqes_mem,
        )
        self._cq = Cq[cqe](params, sq_cq_mem=self.mem.sq_cq_mem)

    fn __del__(owned self):
        # Ensure that `MemoryMapping` is released before `self.fd`
        # as it may depend on it.
        self.mem^.__del__()
        self.fd^.__del__()

    @always_inline
    fn __moveinit__(inout self, owned existing: Self):
        """Moves data of an existing IoUring into a new one.

        Args:
            existing: The existing IoUring.
        """
        self._sq = existing._sq^
        self._cq = existing._cq^
        self.fd = existing.fd^
        self.mem = existing.mem^

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn sq(
        inout self,
    ) -> SqRef[sqe, polling, __lifetime_of(self)]:
        self.sync_sq_head()
        return self.unsynced_sq()

    @always_inline
    fn unsynced_sq(
        inout self,
    ) -> SqRef[sqe, polling, __lifetime_of(self)]:
        return self._sq

    @always_inline
    fn sync_sq_head(inout self):
        self._sq.sync_head()

    @always_inline
    fn submit_and_wait(inout self, *, wait_nr: UInt32) raises -> UInt32:
        return self.submit_and_wait(wait_nr=wait_nr, arg=NO_ENTER_ARG)

    @always_inline
    fn submit_and_wait(
        inout self, *, wait_nr: UInt32, arg: EnterArg
    ) raises -> UInt32:
        var submitted = self._sq.flush()
        var flags = IoUringEnterFlags()

        var cq_needs_enter = wait_nr > 0 or self.cq_needs_enter()

        if self.sq_needs_enter(submitted, flags) or cq_needs_enter:
            if cq_needs_enter:
                flags |= IoUringEnterFlags.GETEVENTS
            return self.enter(
                to_submit=submitted, min_complete=wait_nr, flags=flags, arg=arg
            )

        return submitted

    @always_inline
    fn sq_needs_enter(
        self, submitted: UInt32, inout flags: IoUringEnterFlags
    ) -> Bool:
        @parameter
        if polling is not SQPOLL:
            return True

        if submitted == 0:
            return False

        # FIXME: Need to use atomic fence here to ensure the kernel
        # can see the store to the `self._sq._tail` before we read the flags.
        # [Reference]: https://github.com/modularml/mojo/issues/3162.

        # TODO: Use `unlikely` intrinsic when it becomes available.
        if self._sq.flags() & IoUringSqFlags.NEED_WAKEUP:
            flags |= IoUringEnterFlags.SQ_WAKEUP
            return True

        return False

    @always_inline
    fn cq(
        inout self, *, wait_nr: UInt32
    ) raises -> CqRef[cqe, __lifetime_of(self)]:
        return self.cq(wait_nr=wait_nr, arg=NO_ENTER_ARG)

    @always_inline
    fn cq(
        inout self, *, wait_nr: UInt32, arg: EnterArg
    ) raises -> CqRef[cqe, __lifetime_of(self)]:
        self.flush_cq(wait_nr, arg)
        return self._cq

    @always_inline
    fn flush_cq(inout self, wait_nr: UInt32, arg: EnterArg) raises:
        self._cq.sync_tail()
        if not self._cq and (wait_nr > 0 or self.cq_needs_flush()):
            _ = self.enter(
                to_submit=0,
                min_complete=wait_nr,
                flags=IoUringEnterFlags.GETEVENTS,
                arg=arg,
            )
            self._cq.sync_tail()

    @always_inline
    fn cq_needs_flush(self) -> Bool:
        return bool(
            self._sq.flags()
            & (IoUringSqFlags.CQ_OVERFLOW | IoUringSqFlags.TASKRUN)
        )

    @always_inline
    fn cq_needs_enter(self) -> Bool:
        @parameter
        if polling is IOPOLL:
            return True
        else:
            return self.cq_needs_flush()

    @always_inline
    fn register(self, arg: RegisterArg) raises -> UInt32:
        return io_uring_register(self.fd, arg)

    @always_inline
    fn enter(
        self,
        *,
        to_submit: UInt32,
        min_complete: UInt32,
        flags: IoUringEnterFlags,
        arg: EnterArg,
    ) raises -> UInt32:
        return io_uring_enter(
            self.fd,
            to_submit=to_submit,
            min_complete=min_complete,
            flags=flags,
            arg=arg,
        )
