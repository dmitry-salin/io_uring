from .ctypes import c_void
from linux_raw.x86_64.errno import *
from memory import UnsafePointer


@register_passable("trivial")
struct Errno(Stringable):
    """The error type for `mojix` APIs.
    It only holds an OS error number, and no extra error info.

    Linux returns negated error numbers, and we leave them in negated form, so
    they are in the range `[-4095; 0)`.
    """

    alias EACCES = Self(errno=EACCES)
    alias EADDRINUSE = Self(errno=EADDRINUSE)
    alias EADDRNOTAVAIL = Self(errno=EADDRNOTAVAIL)
    alias EADV = Self(errno=EADV)
    alias EAFNOSUPPORT = Self(errno=EAFNOSUPPORT)
    alias EAGAIN = Self(errno=EAGAIN)
    alias EALREADY = Self(errno=EALREADY)
    alias EBADE = Self(errno=EBADE)
    alias EBADF = Self(errno=EBADF)
    alias EBADFD = Self(errno=EBADFD)
    alias EBADMSG = Self(errno=EBADMSG)
    alias EBADR = Self(errno=EBADR)
    alias EBADRQC = Self(errno=EBADRQC)
    alias EBADSLT = Self(errno=EBADSLT)
    alias EBFONT = Self(errno=EBFONT)
    alias EBUSY = Self(errno=EBUSY)
    alias ECANCELED = Self(errno=ECANCELED)
    alias ECHILD = Self(errno=ECHILD)
    alias ECHRNG = Self(errno=ECHRNG)
    alias ECOMM = Self(errno=ECOMM)
    alias ECONNABORTED = Self(errno=ECONNABORTED)
    alias ECONNREFUSED = Self(errno=ECONNREFUSED)
    alias ECONNRESET = Self(errno=ECONNRESET)
    alias EDEADLK = Self(errno=EDEADLK)
    alias EDEADLOCK = Self(errno=EDEADLOCK)
    alias EDESTADDRREQ = Self(errno=EDESTADDRREQ)
    alias EDOM = Self(errno=EDOM)
    alias EDOTDOT = Self(errno=EDOTDOT)
    alias EDQUOT = Self(errno=EDQUOT)
    alias EEXIST = Self(errno=EEXIST)
    alias EFAULT = Self(errno=EFAULT)
    alias EFBIG = Self(errno=EFBIG)
    alias EHOSTDOWN = Self(errno=EHOSTDOWN)
    alias EHOSTUNREACH = Self(errno=EHOSTUNREACH)
    alias EHWPOISON = Self(errno=EHWPOISON)
    alias EIDRM = Self(errno=EIDRM)
    alias EILSEQ = Self(errno=EILSEQ)
    alias EINPROGRESS = Self(errno=EINPROGRESS)
    alias EINTR = Self(errno=EINTR)
    alias EINVAL = Self(errno=EINVAL)
    alias EIO = Self(errno=EIO)
    alias EISCONN = Self(errno=EISCONN)
    alias EISDIR = Self(errno=EISDIR)
    alias EISNAM = Self(errno=EISNAM)
    alias EKEYEXPIRED = Self(errno=EKEYEXPIRED)
    alias EKEYREJECTED = Self(errno=EKEYREJECTED)
    alias EKEYREVOKED = Self(errno=EKEYREVOKED)
    alias EL2HLT = Self(errno=EL2HLT)
    alias EL2NSYNC = Self(errno=EL2NSYNC)
    alias EL3HLT = Self(errno=EL3HLT)
    alias EL3RST = Self(errno=EL3RST)
    alias ELIBACC = Self(errno=ELIBACC)
    alias ELIBBAD = Self(errno=ELIBBAD)
    alias ELIBEXEC = Self(errno=ELIBEXEC)
    alias ELIBMAX = Self(errno=ELIBMAX)
    alias ELIBSCN = Self(errno=ELIBSCN)
    alias ELNRNG = Self(errno=ELNRNG)
    alias ELOOP = Self(errno=ELOOP)
    alias EMEDIUMTYPE = Self(errno=EMEDIUMTYPE)
    alias EMFILE = Self(errno=EMFILE)
    alias EMLINK = Self(errno=EMLINK)
    alias EMSGSIZE = Self(errno=EMSGSIZE)
    alias EMULTIHOP = Self(errno=EMULTIHOP)
    alias ENAMETOOLONG = Self(errno=ENAMETOOLONG)
    alias ENAVAIL = Self(errno=ENAVAIL)
    alias ENETDOWN = Self(errno=ENETDOWN)
    alias ENETRESET = Self(errno=ENETRESET)
    alias ENETUNREACH = Self(errno=ENETUNREACH)
    alias ENFILE = Self(errno=ENFILE)
    alias ENOANO = Self(errno=ENOANO)
    alias ENOBUFS = Self(errno=ENOBUFS)
    alias ENOCSI = Self(errno=ENOCSI)
    alias ENODATA = Self(errno=ENODATA)
    alias ENODEV = Self(errno=ENODEV)
    alias ENOENT = Self(errno=ENOENT)
    alias ENOEXEC = Self(errno=ENOEXEC)
    alias ENOKEY = Self(errno=ENOKEY)
    alias ENOLCK = Self(errno=ENOLCK)
    alias ENOLINK = Self(errno=ENOLINK)
    alias ENOMEDIUM = Self(errno=ENOMEDIUM)
    alias ENOMEM = Self(errno=ENOMEM)
    alias ENOMSG = Self(errno=ENOMSG)
    alias ENONET = Self(errno=ENONET)
    alias ENOPKG = Self(errno=ENOPKG)
    alias ENOPROTOOPT = Self(errno=ENOPROTOOPT)
    alias ENOSPC = Self(errno=ENOSPC)
    alias ENOSR = Self(errno=ENOSR)
    alias ENOSTR = Self(errno=ENOSTR)
    alias ENOSYS = Self(errno=ENOSYS)
    alias ENOTBLK = Self(errno=ENOTBLK)
    alias ENOTCONN = Self(errno=ENOTCONN)
    alias ENOTDIR = Self(errno=ENOTDIR)
    alias ENOTEMPTY = Self(errno=ENOTEMPTY)
    alias ENOTNAM = Self(errno=ENOTNAM)
    alias ENOTRECOVERABLE = Self(errno=ENOTRECOVERABLE)
    alias ENOTSOCK = Self(errno=ENOTSOCK)
    alias ENOTSUP = Self(errno=EOPNOTSUPP)
    """On Linux, `ENOTSUP` has the same value as `EOPNOTSUPP`."""
    alias ENOTTY = Self(errno=ENOTTY)
    alias ENOTUNIQ = Self(errno=ENOTUNIQ)
    alias ENXIO = Self(errno=ENXIO)
    alias EOPNOTSUPP = Self(errno=EOPNOTSUPP)
    alias EOVERFLOW = Self(errno=EOVERFLOW)
    alias EOWNERDEAD = Self(errno=EOWNERDEAD)
    alias EPERM = Self(errno=EPERM)
    alias EPFNOSUPPORT = Self(errno=EPFNOSUPPORT)
    alias EPIPE = Self(errno=EPIPE)
    alias EPROTO = Self(errno=EPROTO)
    alias EPROTONOSUPPORT = Self(errno=EPROTONOSUPPORT)
    alias EPROTOTYPE = Self(errno=EPROTOTYPE)
    alias ERANGE = Self(errno=ERANGE)
    alias EREMCHG = Self(errno=EREMCHG)
    alias EREMOTE = Self(errno=EREMOTE)
    alias EREMOTEIO = Self(errno=EREMOTEIO)
    alias ERESTART = Self(errno=ERESTART)
    alias ERFKILL = Self(errno=ERFKILL)
    alias EROFS = Self(errno=EROFS)
    alias ESHUTDOWN = Self(errno=ESHUTDOWN)
    alias ESOCKTNOSUPPORT = Self(errno=ESOCKTNOSUPPORT)
    alias ESPIPE = Self(errno=ESPIPE)
    alias ESRCH = Self(errno=ESRCH)
    alias ESRMNT = Self(errno=ESRMNT)
    alias ESTALE = Self(errno=ESTALE)
    alias ESTRPIPE = Self(errno=ESTRPIPE)
    alias ETIME = Self(errno=ETIME)
    alias ETIMEDOUT = Self(errno=ETIMEDOUT)
    alias E2BIG = Self(errno=E2BIG)
    alias ETOOMANYREFS = Self(errno=ETOOMANYREFS)
    alias ETXTBSY = Self(errno=ETXTBSY)
    alias EUCLEAN = Self(errno=EUCLEAN)
    alias EUNATCH = Self(errno=EUNATCH)
    alias EUSERS = Self(errno=EUSERS)
    alias EWOULDBLOCK = Self(errno=EWOULDBLOCK)
    alias EXDEV = Self(errno=EXDEV)
    alias EXFULL = Self(errno=EXDEV)

    var id: Int16
    """The error number."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self, *, errno: UInt16):
        """Constructs an Errno from the error number.

        Args:
            errno: The error number.
        """
        self = Self(negated_errno=-errno.cast[DType.int16]())

    @always_inline("nodebug")
    fn __init__(inout self, *, error: Error) raises:
        """Constructs an Errno from the Error message.

        Args:
            error: The Error message.

        Raises:
            If the given Error message cannot be parsed as an integer value.
        """
        self = Self(negated_errno=int(str(error)))

    @always_inline("nodebug")
    fn __init__(inout self, *, negated_errno: Int16):
        """Constructs an Errno from the negated error number.

        Args:
            negated_errno: The negated error number.
        """
        self.id = negated_errno
        # Linux returns negated error numbers in the range `[-4095; 0)`.
        debug_assert(
            self.id >= -4095 and self.id < 0, "error number out of range"
        )

    # ===-------------------------------------------------------------------===#
    # Operator dunders
    # ===-------------------------------------------------------------------===#

    @always_inline("nodebug")
    fn __is__(self, rhs: Self) -> Bool:
        """Defines whether one Errno has the same identity as another.

        Args:
            rhs: The Errno to compare against.

        Returns:
            True if the Errnos have the same identity, False otherwise.
        """
        return self.id == rhs.id

    @always_inline("nodebug")
    fn __isnot__(self, rhs: Self) -> Bool:
        """Defines whether one Errno has a different identity than another.

        Args:
            rhs: The Errno to compare against.

        Returns:
            True if the Errnos have different identities, False otherwise.
        """
        return self.id != rhs.id

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    @always_inline("nodebug")
    fn __str__(self) -> String:
        """Converts Errno to a string representation.

        Returns:
            A String of the error number.
        """
        return str(self.id)


@always_inline("nodebug")
fn _check_for_errors(raw: Scalar[DType.index]) raises:
    if raw < 0:
        # Linux returns negated error numbers in the range `[-4095; 0)`.
        debug_assert(raw >= -4095, "error number out of range")
        raise str(raw)


@always_inline("nodebug")
fn _zero_result(raw: Scalar[DType.index]):
    debug_assert(raw == 0, "non-zero result")


@always_inline("nodebug")
fn unsafe_decode_result[
    type: DType
](raw: Scalar[DType.index]) raises -> Scalar[type]:
    """Unsafely checks for an error in the result of a syscall that encodes
    the value of the specified type on success.

    Parameters:
        type: The `DType` of the result.

    Args:
        raw: The result of a syscall.

    Returns:
        The value of the specified type.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        This should only be used with syscalls that return a value of the given
        `type` on success.
    """
    _check_for_errors(raw)
    res = raw.cast[type]()
    debug_assert(res.cast[DType.index]() == raw, "conversion is not lossless")
    return res


@always_inline("nodebug")
fn unsafe_decode_ptr(unsafe_ptr: UnsafePointer[c_void]) raises:
    """Unsafely checks for an error in the result of a syscall that encodes
    a pointer on success.

    Args:
        unsafe_ptr: The result of a syscall.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        This should only be used with pointers returned by a syscall.
    """
    _check_for_errors(__mlir_op.`pop.pointer_to_index`(unsafe_ptr.address))


@always_inline("nodebug")
fn unsafe_decode_none(raw: Scalar[DType.index]) raises:
    """Unsafely checks for an error in the result of a syscall that encodes
    a `NoneType` value on success.

    Args:
        raw: The result of a syscall.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        This should only be used with syscalls that return a `NoneType` value
        on success.
    """
    if raw != 0:
        # Linux returns negated error numbers in the range `[-4095; 0)`.
        debug_assert(raw >= -4095 and raw < 0, "error number out of range")
        raise str(raw)
