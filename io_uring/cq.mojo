from .mm import Region
from .utils import AtomicOrdering, _atomic_load, _atomic_store
from mojix.io_uring import Cqe, CQE, CQE16, CQE32, IoUringParams
from mojix.utils import _size_eq, _align_eq
from builtin.builtin_list import _lit_mut_cast
from memory import UnsafePointer


struct Cq[type: CQE](Movable, Sized, Boolable):
    """Completion Queue."""

    var _head: UnsafePointer[UInt32]
    var _tail: UnsafePointer[UInt32]
    var flags: UnsafePointer[UInt32]
    var overflow: UnsafePointer[UInt32]
    var cqes: UnsafePointer[Cqe[type]]

    var cqe_head: UInt32
    var cqe_tail: UInt32

    var ring_mask: UInt32
    var ring_entries: UInt32

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(inout self, params: IoUringParams, *, sq_cq_mem: Region) raises:
        constrained[
            type is CQE16 or type is CQE32,
            "CQE must be equal to CQE16 or CQE32",
        ]()
        _size_eq[Cqe[type], type.size]()
        _align_eq[Cqe[type], type.align]()

        self._head = sq_cq_mem.unsafe_ptr[UInt32](
            offset=params.cq_off.head, count=1
        )
        self._tail = sq_cq_mem.unsafe_ptr[UInt32](
            offset=params.cq_off.tail, count=1
        )
        self.flags = sq_cq_mem.unsafe_ptr[UInt32](
            offset=params.cq_off.flags, count=1
        )
        self.overflow = sq_cq_mem.unsafe_ptr[UInt32](
            offset=params.cq_off.overflow, count=1
        )
        self.ring_mask = sq_cq_mem.unsafe_ptr[UInt32](
            offset=params.cq_off.ring_mask, count=1
        )[]
        self.ring_entries = sq_cq_mem.unsafe_ptr[UInt32](
            offset=params.cq_off.ring_entries, count=1
        )[]
        # We expect the kernel copies `params.cq_entries` to the UInt32
        # pointed to by `params.cq_off.ring_entries`.
        # [Linux]: https://github.com/torvalds/linux/blob/v6.7/io_uring/io_uring.c#L3830.
        if self.ring_entries != params.cq_entries or self.ring_entries == 0:
            raise "invalid cq ring_entries value"
        if self.ring_mask != self.ring_entries - 1:
            raise "invalid cq ring_mask value"

        self.cqes = sq_cq_mem.unsafe_ptr[Cqe[type]](
            offset=params.cq_off.cqes, count=self.ring_entries
        )
        self.cqe_head = self._head[]
        self.cqe_tail = self._tail[]

    @always_inline
    fn __moveinit__(inout self, owned existing: Self):
        """Moves data of an existing Cq into a new one.

        Args:
            existing: The existing Cq.
        """
        self._head = existing._head
        self._tail = existing._tail
        self.flags = existing.flags
        self.overflow = existing.overflow
        self.cqes = existing.cqes
        self.cqe_head = existing.cqe_head
        self.cqe_tail = existing.cqe_tail
        self.ring_mask = existing.ring_mask
        self.ring_entries = existing.ring_entries

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __len__(self) -> Int:
        """Returns the number of entries in the cq.

        Returns:
            The number of entries in the cq.
        """
        return (self.cqe_tail - self.cqe_head).cast[DType.index]().value

    @always_inline
    fn __bool__(self) -> Bool:
        """Checks whether the cq has any entries or not.

        Returns:
            `False` if the cq is empty, `True` if there is at least one entry.
        """
        return self.cqe_head != self.cqe_tail

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn sync_tail(inout self):
        self.cqe_tail = self.tail()

    @always_inline
    fn sync_head(inout self):
        _atomic_store(self._head, self.cqe_head)

    @always_inline
    fn tail(self) -> UInt32:
        return _atomic_load[AtomicOrdering.ACQUIRE](self._tail)


@register_passable
struct CqRef[type: CQE, cq_lifetime: MutableLifetime](Sized, Boolable):
    var cq: Reference[Cq[type], cq_lifetime]

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(inout self, ref [cq_lifetime]cq: Cq[type]):
        self.cq = cq

    @always_inline
    fn __del__(owned self):
        self.cq[].sync_head()

    # ===------------------------------------------------------------------=== #
    # Operator dunders
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __iter__(owned self) -> Self:
        return self^

    @always_inline
    fn __next__[
        lifetime: MutableLifetime
    ](ref [lifetime]self) -> ref [_lit_mut_cast[lifetime, False].result] Cqe[
        type
    ]:
        ptr = self.cq[].cqes.offset(
            int(self.cq[].cqe_head & self.cq[].ring_mask)
        )
        self.cq[].cqe_head += 1
        return ptr[]

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __len__(self) -> Int:
        """Returns the number of entries in the cq.

        Returns:
            The number of entries in the cq.
        """
        return len(self.cq[])

    @always_inline
    fn __bool__(self) -> Bool:
        """Checks whether the cq has any entries or not.

        Returns:
            `False` if the cq is empty, `True` if there is at least one entry.
        """
        return bool(self.cq[])
