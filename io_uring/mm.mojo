from .cq import Cq
from .params import Entries
from .utils import _add_with_overflow
from mojix.ctypes import c_void
from mojix.io_uring import (
    Sqe,
    SQE,
    Cqe,
    CQE,
    IoUringParams,
    IoUringSetupFlags,
)
from mojix.errno import Errno
from mojix.fd import FileDescriptor
from mojix.mm import (
    mmap,
    mmap_anonymous,
    munmap,
    madvise,
    ProtFlags,
    MapFlags,
    Advice,
)
from sys.info import alignof, sizeof
from memory import UnsafePointer


struct Region(Movable):
    var ptr: UnsafePointer[c_void]
    var len: UInt

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__[
        Fd: FileDescriptor
    ](out self, *, fd: Fd, offset: UInt64, len: UInt) raises:
        self.ptr = mmap(
            unsafe_ptr=UnsafePointer[c_void](),
            len=len,
            prot=ProtFlags.READ | ProtFlags.WRITE,
            flags=MapFlags.SHARED | MapFlags.POPULATE,
            fd=fd,
            offset=offset,
        )
        debug_assert(self.ptr, "null pointer")
        self.len = len

    @always_inline
    fn __init__(out self, *, len: UInt, flags: MapFlags) raises:
        self.ptr = mmap_anonymous(
            unsafe_ptr=UnsafePointer[c_void](),
            len=len,
            prot=ProtFlags.READ | ProtFlags.WRITE,
            flags=MapFlags.SHARED | MapFlags.POPULATE | flags,
        )
        debug_assert(self.ptr, "null pointer")
        self.len = len

    @always_inline
    fn __del__(owned self):
        try:
            munmap(unsafe_ptr=self.ptr, len=self.len)
        except:
            pass

    @always_inline
    fn __moveinit__(out self, owned existing: Self):
        """Moves data of an existing Region into a new one.

        Args:
            existing: The existing Region.
        """
        self.ptr = existing.ptr
        self.len = existing.len

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn dontfork(self) raises:
        madvise(unsafe_ptr=self.ptr, len=self.len, advice=Advice.DONTFORK)

    @always_inline
    fn unsafe_ptr[
        T: AnyType
    ](self, *, offset: UInt32, count: UInt32) raises -> UnsafePointer[T]:
        constrained[alignof[T]() > 0]()
        constrained[sizeof[c_void]() == 1]()

        len = _add_with_overflow(offset, count * sizeof[T]())
        if len[1]:
            raise "len overflow"
        if len[0] > self.len:
            raise "offset is out of bounds"
        ptr = self.ptr.offset(Int(offset))
        if Int(ptr) & (alignof[T]() - 1):
            raise "region is not properly aligned"
        return ptr.bitcast[T]()

    @always_inline
    fn addr(self) -> UInt64:
        return Int(self.ptr)


struct MemoryMapping[sqe: SQE, cqe: CQE](Movable):
    var sqes_mem: Region
    var sq_cq_mem: Region

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(out self, *, owned sqes_mem: Region, owned sq_cq_mem: Region):
        self.sqes_mem = sqes_mem^
        self.sq_cq_mem = sq_cq_mem^

    fn __init__(out self, sq_entries: UInt32, mut params: IoUringParams) raises:
        entries = Entries(sq_entries=sq_entries, params=params)
        # FIXME: Get the actual page size value at runtime.
        alias page_size = 4096
        sqes_size = entries.sq_entries * sqe.size
        sq_array_size = (
            0 if params.flags
            & IoUringSetupFlags.NO_SQARRAY else entries.sq_entries
            * sizeof[UInt32]()
        )
        sq_cq_size = (
            cqe.rings_size + entries.cq_entries * cqe.size + sq_array_size
        )

        alias HUGE_PAGE_SIZE = 1 << 21
        if sqes_size > HUGE_PAGE_SIZE or sq_cq_size > HUGE_PAGE_SIZE:
            raise String(Errno.ENOMEM)

        flags = MapFlags()
        if sqes_size <= page_size:
            sqes_size = page_size
        else:
            sqes_size = HUGE_PAGE_SIZE
            flags |= MapFlags.HUGETLB | MapFlags.HUGE_2MB

        self.sqes_mem = Region(
            len=UInt(sqes_size.cast[DType.index]().value), flags=flags
        )

        flags = MapFlags()
        if sq_cq_size <= page_size:
            sq_cq_size = page_size
        else:
            sq_cq_size = HUGE_PAGE_SIZE
            flags |= MapFlags.HUGETLB | MapFlags.HUGE_2MB

        self.sq_cq_mem = Region(
            len=UInt(sq_cq_size.cast[DType.index]().value), flags=flags
        )

        params.cq_off.user_addr = self.sq_cq_mem.addr()
        params.sq_off.user_addr = self.sqes_mem.addr()

    @always_inline
    fn __moveinit__(out self, owned existing: Self):
        """Moves data of an existing MemoryMapping into a new one.

        Args:
            existing: The existing MemoryMapping.
        """
        self.sqes_mem = existing.sqes_mem^
        self.sq_cq_mem = existing.sq_cq_mem^

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn dontfork(self) raises:
        self.sqes_mem.dontfork()
        self.sq_cq_mem.dontfork()
