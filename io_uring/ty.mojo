from mojix import sigset_t
from mojix.ctypes import c_void
from mojix.io_uring import EnterArg, IoUringEnterFlags, IoUringGetEventsArg
from mojix.timespec import Timespec
from sys.info import sizeof
from memory import UnsafePointer


struct WaitArg[
    sigmask_origin: ImmutableOrigin,
    timespec_origin: ImmutableOrigin,
]:
    alias enter_flags = IoUringEnterFlags.EXT_ARG

    var arg: IoUringGetEventsArg

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(out self):
        self.arg = IoUringGetEventsArg()

    @always_inline
    fn __init__[
        origin: ImmutableOrigin
    ](
        out self: WaitArg[origin, StaticConstantOrigin],
        ref [origin]sigmask: sigset_t,
    ):
        self.arg = IoUringGetEventsArg(
            Int(UnsafePointer.address_of(sigmask)), sizeof[sigset_t](), 0, 0
        )

    @always_inline
    fn __init__[
        origin: ImmutableOrigin
    ](
        out self: WaitArg[StaticConstantOrigin, origin],
        ref [origin]timespec: Timespec,
    ):
        self.arg = IoUringGetEventsArg(
            0, 0, 0, Int(UnsafePointer.address_of(timespec))
        )

    @always_inline
    fn __init__(
        out self,
        ref [sigmask_origin]sigmask: sigset_t,
        ref [timespec_origin]timespec: Timespec,
    ):
        self.arg = IoUringGetEventsArg(
            Int(UnsafePointer.address_of(sigmask)),
            sizeof[sigset_t](),
            0,
            Int(UnsafePointer.address_of(timespec)),
        )

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn as_enter_arg(
        self,
    ) -> EnterArg[
        sizeof[IoUringGetEventsArg](),
        Self.enter_flags,
        __origin_of(self),
    ]:
        return EnterArg[
            sizeof[IoUringGetEventsArg](), Self.enter_flags, __origin_of(self)
        ](arg_unsafe_ptr=UnsafePointer.address_of(self.arg).bitcast[c_void]())
