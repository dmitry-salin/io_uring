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


trait OwnedFileDescriptor(
    FileDescriptor,
    AsFileDescriptor,
    AsUnsafeFileDescriptor,
    FromUnsafeFileDescriptor,
    Movable,
):
    ...


trait FileDescriptor:
    fn __getitem__[
        lifetime: ImmutableLifetime
    ](ref [lifetime]self) -> Fd[lifetime]:
        ...


trait AsFileDescriptor:
    fn as_fd[lifetime: ImmutableLifetime](ref [lifetime]self) -> Fd[lifetime]:
        ...


trait AsUnsafeFileDescriptor:
    """A trait to extract the unsafe file descriptor from an underlying object."""

    fn as_unsafe_fd(self) -> UnsafeFd:
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


trait FromUnsafeFileDescriptor:
    fn __init__(inout self, *, unsafe_fd: UnsafeFd):
        ...


@register_passable
struct OwnedFd(OwnedFileDescriptor):
    """An owned file descriptor that is automatically closed in its destructor.
    """

    var fd: UnsafeFd
    """The underlying file descriptor."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self, *, unsafe_fd: UnsafeFd):
        """Constructs an OwnedFd from an unsafe file descriptor.

        Args:
            unsafe_fd: The unsafe file descriptor.

        Safety:
            The resource pointed to by `unsafe_fd` must be open and suitable for
            assuming ownership. The resource must not require any cleanup other
            than `close`.
        """

        # The value of `unsafe_fd` should be in the valid range and not `-1`.
        debug_assert(unsafe_fd > -1, "invalid file descriptor")
        self.fd = unsafe_fd

    @always_inline("nodebug")
    fn __del__(owned self):
        """Closes the file descriptor."""
        close(unsafe_fd=self.fd)

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __getitem__[
        lifetime: ImmutableLifetime
    ](ref [lifetime]self) -> Fd[lifetime]:
        return Fd[lifetime](unsafe_fd=self.fd)

    @always_inline("nodebug")
    fn as_fd[lifetime: ImmutableLifetime](ref [lifetime]self) -> Fd[lifetime]:
        return self.__getitem__()

    @always_inline("nodebug")
    fn as_unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self.fd


@register_passable("trivial")
struct Fd[lifetime: ImmutableLifetime](AsUnsafeFileDescriptor):
    var fd: UnsafeFd

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self, *, unsafe_fd: UnsafeFd):
        self.fd = unsafe_fd

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn as_unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self.fd


@register_passable
struct IoUringOwnedFd[is_registered: Bool](AsUnsafeFileDescriptor, Movable):
    """An owned `io_uring` file descriptor that is automatically 
    closed/unregistered in its destructor.
    """

    alias SETUP_FLAGS = IoUringSetupFlags.REGISTERED_FD_ONLY | IoUringSetupFlags.NO_MMAP
        if is_registered else IoUringSetupFlags()

    var fd: UnsafeFd
    """The underlying file descriptor."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self, *, unsafe_fd: UnsafeFd):
        """Constructs an IoUringOwnedFd from an unsafe file descriptor.

        Args:
            unsafe_fd: The unsafe file descriptor.

        Safety:
            The `unsafe_fd` must be returned by a successful call
            to `io_uring_setup`.
        """

        debug_assert(unsafe_fd > -1, "invalid `io_uring` file descriptor")
        self.fd = unsafe_fd

    @always_inline("nodebug")
    fn __del__(owned self):
        """Closes/unregisters the file descriptor."""
        @parameter
        if is_registered:
            var op = IoUringRsrcUpdate(self.fd.cast[UInt32.element_type](), 0, 0)
            var arg = op.as_register_arg(unsafe_opcode=IoUringRegisterOp.UNREGISTER_RING_FDS)
            try:
                var res = io_uring_register(self[], arg)
                debug_assert(res == 1, "failed to unregister file descriptor")
            except:
                pass
        else:    
            close(unsafe_fd=self.fd)

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #
    
    @always_inline("nodebug")
    fn as_unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self.fd

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline("nodebug")
    fn __getitem__[
        lifetime: ImmutableLifetime
    ](ref [lifetime]self) -> IoUringFd[is_registered, lifetime]:
        return IoUringFd[is_registered, lifetime](unsafe_fd=self.fd)

    @always_inline("nodebug")
    fn as_fd[lifetime: ImmutableLifetime](ref [lifetime]self) -> Fd[lifetime]:
        constrained[not is_registered]()
        return Fd[lifetime](unsafe_fd=self.fd)


@register_passable("trivial")
struct IoUringFd[is_registered: Bool, lifetime: ImmutableLifetime](
    AsUnsafeFileDescriptor
):
    alias REGISTER_FLAGS = IoUringRegisterFlags.REGISTER_USE_REGISTERED_RING
        if is_registered else IoUringRegisterFlags()

    alias ENTER_FLAGS = IoUringEnterFlags.REGISTERED_RING if is_registered
        else IoUringEnterFlags()

    alias SQE_FLAGS = IoUringSqeFlags.FIXED_FILE if is_registered
        else IoUringSqeFlags()

    var fd: UnsafeFd

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self, *, unsafe_fd: UnsafeFd):
        self.fd = unsafe_fd

    @always_inline("nodebug")
    fn __init__[
        lifetime: ImmutableLifetime
    ](inout self: IoUringFd[False, lifetime], *, fd: Fd[lifetime]):
        self.fd = fd.as_unsafe_fd()

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn as_unsafe_fd(self) -> UnsafeFd:
        """Extracts an unsafe file descriptor.

        Returns:
            The unsafe file descriptor.
        """
        return self.fd


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
