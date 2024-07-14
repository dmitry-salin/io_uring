from mojix import sigset_t
from mojix.ctypes import c_void
from mojix.io_uring import EnterArg, IoUringEnterFlags, IoUringGetEventsArg
from mojix.timespec import Timespec


struct WaitArg[
    sigmask_lifetime: ImmutableLifetime,
    timespec_lifetime: ImmutableLifetime,
]:
    alias enter_flags = IoUringEnterFlags.EXT_ARG

    var arg: IoUringGetEventsArg

    @always_inline("nodebug")
    fn __init__(inout self):
        self.arg = IoUringGetEventsArg()

    @always_inline("nodebug")
    fn __init__[
        lifetime: ImmutableLifetime
    ](
        inout self: WaitArg[lifetime, ImmutableStaticLifetime],
        ref [lifetime]sigmask: sigset_t,
    ):
        self.arg = IoUringGetEventsArg(
            int(UnsafePointer.address_of(sigmask)), sizeof[sigset_t](), 0, 0
        )

    @always_inline("nodebug")
    fn __init__[
        lifetime: ImmutableLifetime
    ](
        inout self: WaitArg[ImmutableStaticLifetime, lifetime],
        ref [lifetime]timespec: Timespec,
    ):
        self.arg = IoUringGetEventsArg(
            0, 0, 0, int(UnsafePointer.address_of(timespec))
        )

    @always_inline("nodebug")
    fn __init__(
        inout self,
        ref [sigmask_lifetime]sigmask: sigset_t,
        ref [timespec_lifetime]timespec: Timespec,
    ):
        self.arg = IoUringGetEventsArg(
            int(UnsafePointer.address_of(sigmask)),
            sizeof[sigset_t](),
            0,
            int(UnsafePointer.address_of(timespec)),
        )

    @always_inline("nodebug")
    fn as_enter_arg(
        self,
    ) -> EnterArg[
        __lifetime_of(self),
        sizeof[IoUringGetEventsArg](),
        IoUringEnterFlags.EXT_ARG,
    ]:
        return EnterArg[
            __lifetime_of(self),
            sizeof[IoUringGetEventsArg](),
            Self.enter_flags,
        ](arg_unsafe_ptr=UnsafePointer.address_of(self.arg).bitcast[c_void]())
