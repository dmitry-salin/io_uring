from .close import close
from .ctypes import c_int
from .io_uring import (
    io_uring_register,
    IoUringSetupFlags,
    IoUringRegisterOp,
    IoUringRegisterFlags,
    IoUringEnterFlags,
    IoUringSqeFlags,
    IoUringRsrcUpdate
)


alias UnsafeFd = c_int
"""An unsafe file descriptor.
 It represents identifiers that can be passed to low-level OS APIs.
 """
alias NoFd = -1
"""Can be used to pass an unsafe file descriptor argument to syscalls
like `mmap`, where it indicates that the argument is omitted.
"""


trait FromUnsafeFileDescriptor:
    fn __init__(out self, *, unsafe_fd: UnsafeFd):
        ...


trait UnsafeFileDescriptor:
    """A trait to extract the unsafe file descriptor from an underlying object."""

    fn unsafe_fd(self) -> UnsafeFd:
        """Extracts the unsafe file descriptor.

        This function is typically used to "borrow" an owned file descriptor.
        When used in this way, this method does not pass ownership of the
        file descriptor to the caller, and the file descriptor is only
        guaranteed to be valid while the original object has not yet been
        destroyed.

        Returns:
            The unsafe file descriptor.
        """
        ...


trait FileDescriptor(
    FromUnsafeFileDescriptor,
    UnsafeFileDescriptor,
    Movable
):
    fn fd(self) -> Fd:
        ...


trait IoUringFileDescriptor(
    FromUnsafeFileDescriptor,
    UnsafeFileDescriptor,
    Movable
):
    alias IS_REGISTERED: Bool
    alias SETUP_FLAGS: IoUringSetupFlags
    alias REGISTER_FLAGS: IoUringRegisterFlags
    alias ENTER_FLAGS: IoUringEnterFlags
    alias SQE_FLAGS: IoUringSqeFlags

    fn io_uring_fd(self) -> IoUringFd[IS_REGISTERED]:
        ...


@register_passable("trivial")
struct Fd[origin: ImmutableOrigin = ImmutableAnyOrigin](
    FileDescriptor,
    IoUringFileDescriptor,
):
    alias IS_REGISTERED = False
    alias SETUP_FLAGS = IoUringSetupFlags()
    alias REGISTER_FLAGS = IoUringRegisterFlags()
    alias ENTER_FLAGS = IoUringEnterFlags()
    alias SQE_FLAGS = IoUringSqeFlags()

    var _fd: UnsafeFd

    @always_inline("nodebug")
    fn __init__(out self, *, unsafe_fd: UnsafeFd):
        """Constructs an Fd from an unsafe file descriptor.

        Args:
            unsafe_fd: The unsafe file descriptor.

        Safety:
            The resource pointed to by `unsafe_fd` must be open.
        """

        self._fd = unsafe_fd

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self._fd

    @always_inline("nodebug")
    fn fd(self) -> Fd:
        return Fd(unsafe_fd=self._fd)

    @always_inline("nodebug")
    fn io_uring_fd(self) -> IoUringFd[Self.IS_REGISTERED]:
        return IoUringFd[Self.IS_REGISTERED](unsafe_fd=self._fd)


@register_passable("trivial")
struct IoUringFd[is_registered: Bool](FileDescriptor, IoUringFileDescriptor):
    alias IS_REGISTERED = is_registered

    alias SETUP_FLAGS = IoUringSetupFlags.REGISTERED_FD_ONLY | IoUringSetupFlags.NO_MMAP
        if is_registered else IoUringSetupFlags()

    alias REGISTER_FLAGS = IoUringRegisterFlags.REGISTER_USE_REGISTERED_RING
        if is_registered else IoUringRegisterFlags()

    alias ENTER_FLAGS = IoUringEnterFlags.REGISTERED_RING if is_registered
        else IoUringEnterFlags()

    alias SQE_FLAGS = IoUringSqeFlags.FIXED_FILE if is_registered
        else IoUringSqeFlags()

    var _fd: UnsafeFd

    @always_inline("nodebug")
    fn __init__(out self, *, unsafe_fd: UnsafeFd):
        """Constructs an IoUringFd from an unsafe file descriptor.

        Args:
            unsafe_fd: The unsafe file descriptor.

        Safety:
            The resource pointed to by `unsafe_fd` must be open.
        """

        self._fd = unsafe_fd

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self._fd

    @always_inline("nodebug")
    fn fd(self) -> Fd:
        constrained[not is_registered]()
        return Fd(unsafe_fd=self._fd)

    @always_inline("nodebug")
    fn io_uring_fd(self) -> IoUringFd[is_registered]:
        return self


@value
@register_passable
struct OwnedFd[is_registered: Bool = False](FileDescriptor, IoUringFileDescriptor):
    """An owned file descriptor that is automatically closed/unregistered
    in its destructor.
    """
    alias IS_REGISTERED = is_registered
    alias SETUP_FLAGS = IoUringFd[is_registered].SETUP_FLAGS
    alias REGISTER_FLAGS = IoUringFd[is_registered].REGISTER_FLAGS
    alias ENTER_FLAGS = IoUringFd[is_registered].ENTER_FLAGS
    alias SQE_FLAGS = IoUringFd[is_registered].SQE_FLAGS

    var _fd: UnsafeFd
    """The underlying file descriptor."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(out self, *, unsafe_fd: UnsafeFd):
        """Constructs an OwnedFd from an unsafe file descriptor.

        Args:
            unsafe_fd: The unsafe file descriptor.

        Safety:
            The resource pointed to by `unsafe_fd` must be open and suitable for
            assuming ownership. The resource must not require any cleanup other
            than `close/unregister`.
        """

        debug_assert(unsafe_fd > -1, "invalid file descriptor")
        self._fd = unsafe_fd

    @always_inline("nodebug")
    fn __del__(owned self):
        """Closes/unregisters the file descriptor."""
        @parameter
        if is_registered:
            op = IoUringRsrcUpdate(self._fd.cast[DType.uint32](), 0, 0)
            arg = op.as_register_arg(unsafe_opcode=IoUringRegisterOp.UNREGISTER_RING_FDS)
            try:
                res = io_uring_register(self, arg)
                debug_assert(res == 1, "failed to unregister file descriptor")
            except:
                pass
        else:    
            close(unsafe_fd=self._fd)

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self._fd

    @always_inline("nodebug")
    fn fd(self) -> Fd:
        constrained[not is_registered]()
        return Fd(unsafe_fd=self._fd)

    @always_inline("nodebug")
    fn io_uring_fd(self) -> IoUringFd[is_registered]:
        return IoUringFd[is_registered](unsafe_fd=self._fd)


@always_inline("nodebug")
fn unsafe_fd_as_arg(unsafe_fd: UnsafeFd) -> UnsafeFd:
    """Unsafely passes a file descriptor as an argument to the syscall.

    Args:
        unsafe_fd: The unsafe file descriptor.

    Returns:
        The unsafe file descriptor that can be passed to the syscall.

    Safety:
        The `unsafe_fd` must be a valid open file descriptor.
    """

    # TODO: Add more debug_assert's (check for IORING_REGISTER_FILES_SKIP).

    # The value of `unsafe_fd` should be in the valid range and not `-1`.
    debug_assert(unsafe_fd > -1, "invalid file descriptor")
    return unsafe_fd
