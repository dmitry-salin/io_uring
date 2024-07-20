from .errno import _zero_result
from .fd import UnsafeFd, unsafe_fd_as_arg
from linux_raw.x86_64.general import __NR_close
from linux_raw.x86_64.syscall import syscall


@always_inline
fn close(*, unsafe_fd: UnsafeFd):
    """Closes an unsafe file descriptor directly.

    Most users won't need to use this, as `OwnedFd` automatically closes its
    file descriptor in its destructor.

    This function does not raise any errors, as it is the [responsibility] of
    filesystem designers to not return errors from `close`. Users who chose to
    use NFS or similar filesystems should take care to monitor for problems
    externally.

    [responsibility]: https://lwn.net/Articles/576518.

    Args:
        unsafe_fd: The unsafe file descriptor.

    Safety:
        The file descriptor must be valid before the call, and is not valid
        after the call.
    """
    var res = syscall[__NR_close, Scalar[DType.index], uses_memory=False](
        unsafe_fd_as_arg(unsafe_fd)
    )
    _zero_result(res)
