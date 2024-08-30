from .ctypes import c_void, c_uint
from .fd import FileDescriptor, NoFd
from .errno import unsafe_decode_ptr, unsafe_decode_none
from linux_raw.x86_64.general import *
from linux_raw.x86_64.general import __NR_mmap, __NR_munmap, __NR_madvise
from linux_raw.x86_64.syscall import syscall
from sys.info import is_64bit


@always_inline
fn mmap[
    Fd: FileDescriptor
](
    *,
    unsafe_ptr: UnsafePointer[c_void],
    len: UInt,
    prot: ProtFlags,
    flags: MapFlags,
    fd: Fd,
    offset: UInt64,
) raises -> UnsafePointer[c_void]:
    """Unsafely creates a file-backed memory mapping.
    [Linux]: https://man7.org/linux/man-pages/man2/mmap.2.html.

    Args:
        unsafe_ptr: The starting address hint.
        len: The length of the mapping.
        prot: The bitmask of the `ProtFlags` values.
        flags: The bitmask of the `MapFlags` values.
        fd: The file descriptor that refers to the file (or other object)
            containing the mapping.
        offset: The offset in the file (or other object) referred to by `fd`.

    Returns:
        Pointer to the mapped area.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        Unsafe pointers and lots of special semantics.
    """
    constrained[is_64bit()]()

    res = syscall[__NR_mmap, UnsafePointer[c_void]](
        unsafe_ptr, len, prot, flags, fd.unsafe_fd(), offset
    )
    unsafe_decode_ptr(res)
    return res


@always_inline
fn mmap_anonymous(
    *,
    unsafe_ptr: UnsafePointer[c_void],
    len: UInt,
    prot: ProtFlags,
    flags: MapFlags,
) raises -> UnsafePointer[c_void]:
    """Unsafely creates an anonymous memory mapping.
    [Linux]: https://man7.org/linux/man-pages/man2/mmap.2.html.

    Args:
        unsafe_ptr: The starting address hint.
        len: The length of the mapping.
        prot: The bitmask of the `ProtFlags` values.
        flags: The bitmask of the `MapFlags` values.

    Returns:
        Pointer to the mapped area.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        Unsafe pointers and lots of special semantics.
    """
    constrained[is_64bit()]()

    res = syscall[__NR_mmap, UnsafePointer[c_void]](
        unsafe_ptr, len, prot, flags | MapFlags(MAP_ANONYMOUS), NoFd, 0
    )
    unsafe_decode_ptr(res)
    return res


@always_inline
fn munmap(*, unsafe_ptr: UnsafePointer[c_void], len: UInt) raises:
    """Unsafely removes a memory mapping.
    [Linux]: https://man7.org/linux/man-pages/man2/mmap.2.html.

    Args:
        unsafe_ptr: The starting address of the range for which
                    the mapping should be removed.
        len: The length of the address range for which the mapping
             should be removed.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        Unsafe pointers and lots of special semantics.
    """
    res = syscall[__NR_munmap, Scalar[DType.index]](unsafe_ptr, len)
    unsafe_decode_none(res)


@always_inline
fn madvise(
    *, unsafe_ptr: UnsafePointer[c_void], len: UInt, advice: Advice
) raises:
    """Unsafely declares the expected access pattern for the memory mapping.
    [Linux]: https://man7.org/linux/man-pages/man2/madvise.2.html.

    Args:
        unsafe_ptr: Starting address of the mapping range.
        len: The length of the mapping address range.
        advice: One of the `Advice` values.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        `unsafe_ptr` must be a valid pointer to memory that is appropriate
         to call `madvise` on. Some forms of `advice` may mutate the memory
         or evoke a variety of side-effects on the mapping and/or the file.
    """
    res = syscall[__NR_madvise, Scalar[DType.index]](unsafe_ptr, len, advice)
    unsafe_decode_none(res)


@value
@register_passable("trivial")
struct MapFlags(Defaultable):
    """`MAP_*` flags for use with `mmap` and `mmap_anonymous`."""

    alias SHARED = Self(MAP_SHARED)
    alias SHARED_VALIDATE = Self(MAP_SHARED_VALIDATE)
    alias PRIVATE = Self(MAP_PRIVATE)
    alias DENYWRITE = Self(MAP_DENYWRITE)
    alias FIXED = Self(MAP_FIXED)
    alias FIXED_NOREPLACE = Self(MAP_FIXED_NOREPLACE)
    alias GROWSDOWN = Self(MAP_GROWSDOWN)
    alias HUGETLB = Self(MAP_HUGETLB)
    alias HUGE_2MB = Self(MAP_HUGE_2MB)
    alias HUGE_1GB = Self(MAP_HUGE_1GB)
    alias LOCKED = Self(MAP_LOCKED)
    alias NORESERVE = Self(MAP_NORESERVE)
    alias POPULATE = Self(MAP_POPULATE)
    alias STACK = Self(MAP_STACK)
    alias SYNC = Self(MAP_SYNC)
    alias UNINITIALIZED = Self(MAP_UNINITIALIZED)

    var value: c_uint

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
struct ProtFlags(Defaultable):
    """`PROT_*` flags for use with `mmap`."""

    alias NONE = Self(PROT_NONE)
    alias READ = Self(PROT_READ)
    alias WRITE = Self(PROT_WRITE)
    alias EXEC = Self(PROT_EXEC)

    var value: c_uint

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


@register_passable("trivial")
struct Advice:
    """`POSIX_MADV_*` constants for use with `madvise`."""

    alias NORMAL = Self {id: MADV_NORMAL}
    alias RANDOM = Self {id: MADV_RANDOM}
    alias SEQUENTIAL = Self {id: MADV_SEQUENTIAL}
    alias WILLNEED = Self {id: MADV_WILLNEED}
    alias DONTNEED = Self {id: MADV_DONTNEED}
    alias FREE = Self {id: MADV_FREE}
    alias REMOVE = Self {id: MADV_REMOVE}
    alias DONTFORK = Self {id: MADV_DONTFORK}
    alias DOFORK = Self {id: MADV_DOFORK}
    alias HWPOISON = Self {id: MADV_HWPOISON}
    alias SOFT_OFFLINE = Self {id: MADV_SOFT_OFFLINE}
    alias MERGEABLE = Self {id: MADV_MERGEABLE}
    alias UNMERGEABLE = Self {id: MADV_UNMERGEABLE}
    alias HUGEPAGE = Self {id: MADV_HUGEPAGE}
    alias NOHUGEPAGE = Self {id: MADV_NOHUGEPAGE}
    alias DONTDUMP = Self {id: MADV_DONTDUMP}
    alias DODUMP = Self {id: MADV_DODUMP}
    alias WIPEONFORK = Self {id: MADV_WIPEONFORK}
    alias KEEPONFORK = Self {id: MADV_KEEPONFORK}
    alias COLD = Self {id: MADV_COLD}
    alias PAGEOUT = Self {id: MADV_PAGEOUT}
    alias POPULATE_READ = Self {id: MADV_POPULATE_READ}
    alias POPULATE_WRITE = Self {id: MADV_POPULATE_WRITE}
    alias DONTNEED_LOCKED = Self {id: MADV_DONTNEED_LOCKED}
    alias COLLAPSE = Self {id: MADV_COLLAPSE}

    var id: c_uint
