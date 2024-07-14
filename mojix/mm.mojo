from .ctypes import c_void
from .fd import Fd, NoFd
from .errno import unsafe_decode_ptr, unsafe_decode_none
from linux_raw.x86_64.general import *
from linux_raw.x86_64.general import __NR_mmap, __NR_munmap, __NR_madvise
from linux_raw.x86_64.syscall import syscall
from sys.info import is_64bit


@always_inline
fn mmap(
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
        offset: The offset in the file (or other object) referred to
                by `unsafe_fd`.

    Returns:
        Pointer to the mapped area.

    Raises:
        `Errno` if the syscall returned an error.

    Safety:
        Unsafe pointers and lots of special semantics.
    """
    constrained[is_64bit()]()

    var res = syscall[__NR_mmap, UnsafePointer[c_void]](
        unsafe_ptr, len, prot, flags, fd, offset
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

    var res = syscall[__NR_mmap, UnsafePointer[c_void]](
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
    var res = syscall[__NR_munmap, Scalar[DType.index]](unsafe_ptr, len)
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
    var res = syscall[__NR_madvise, Scalar[DType.index]](
        unsafe_ptr, len, advice
    )
    unsafe_decode_none(res)


@value
@register_passable("trivial")
struct MapFlags(Defaultable):
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


@value
@register_passable("trivial")
struct ProtFlags:
    var value: UInt32

    alias READ = UInt32(PROT_READ)
    alias WRITE = UInt32(PROT_WRITE)
    alias EXEC = UInt32(PROT_EXEC)


@register_passable("trivial")
struct Advice:
    var value: UInt32

    alias NORMAL = Self {value: MADV_NORMAL}
    alias RANDOM = Self {value: MADV_RANDOM}
    alias SEQUENTIAL = Self {value: MADV_SEQUENTIAL}
    alias WILLNEED = Self {value: MADV_WILLNEED}
    alias DONTNEED = Self {value: MADV_DONTNEED}
    alias FREE = Self {value: MADV_FREE}
    alias REMOVE = Self {value: MADV_REMOVE}
    alias DONTFORK = Self {value: MADV_DONTFORK}
    alias DOFORK = Self {value: MADV_DOFORK}
    alias HWPOISON = Self {value: MADV_HWPOISON}
    alias SOFT_OFFLINE = Self {value: MADV_SOFT_OFFLINE}
    alias MERGEABLE = Self {value: MADV_MERGEABLE}
    alias UNMERGEABLE = Self {value: MADV_UNMERGEABLE}
    alias HUGEPAGE = Self {value: MADV_HUGEPAGE}
    alias NOHUGEPAGE = Self {value: MADV_NOHUGEPAGE}
    alias DONTDUMP = Self {value: MADV_DONTDUMP}
    alias DODUMP = Self {value: MADV_DODUMP}
    alias WIPEONFORK = Self {value: MADV_WIPEONFORK}
    alias KEEPONFORK = Self {value: MADV_KEEPONFORK}
    alias COLD = Self {value: MADV_COLD}
    alias PAGEOUT = Self {value: MADV_PAGEOUT}
    alias POPULATE_READ = Self {value: MADV_POPULATE_READ}
    alias POPULATE_WRITE = Self {value: MADV_POPULATE_WRITE}
    alias DONTNEED_LOCKED = Self {value: MADV_DONTNEED_LOCKED}
    alias COLLAPSE = Self {value: MADV_COLLAPSE}
