from .mm import Region
from .utils import AtomicOrdering, _atomic_store, _checked_add
from mojix.ctypes import c_void
from mojix.io_uring import (
    IoUringBufReg,
    IoUringCqeFlags,
    IoUringRegisterOp,
    io_uring_buf,
    IORING_CQE_BUFFER_SHIFT,
)
from mojix.mm import MapFlags
from mojix.utils import _size_eq, _align_eq
from sys import bitwidthof
from sys.info import sizeof
from memory import UnsafePointer


# TODO: mark as @explicit_destroy
struct BufRing:
    var _mem: Region
    var _tail_ptr: UnsafePointer[UInt16]
    var _tail: UInt16
    var _mask: UInt16
    var _buf_ptr: UnsafePointer[c_void]
    var entries: UInt16
    var entry_size: UInt32
    var bgid: UInt16

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(
        out self,
        io_uring: IoUring,
        *,
        bgid: UInt16,
        entries: UInt16,
        entry_size: UInt32,
    ) raises:
        _size_eq[io_uring_buf, 16]()
        _align_eq[io_uring_buf, 8]()
        ring_size = _checked_add(sizeof[io_uring_buf](), entry_size) * UInt32(
            entries
        )
        mem = Region.private(
            len=ring_size.cast[DType.index]().value, flags=MapFlags()
        )

        reg = IoUringBufReg(
            ring_addr=mem.addr(),
            ring_entries=UInt32(entries),
            bgid=bgid,
        )
        res = io_uring.register(
            reg.as_register_arg(
                unsafe_opcode=IoUringRegisterOp.REGISTER_PBUF_RING
            )
        )
        debug_assert(res == 0, "failed to register buffer ring")

        ring_ptr = mem.unsafe_ptr[io_uring_buf](offset=0, count=UInt32(entries))
        # Init tail.
        # [liburing]: https://github.com/axboe/liburing/blob/liburing-2.6/src/include/liburing.h#L1444.
        ring_ptr[].resv = 0

        self._mem = mem^
        self._tail_ptr = UnsafePointer.address_of(ring_ptr[].resv)
        self._tail = self._tail_ptr[]
        self._mask = entries - 1
        self._buf_ptr = ring_ptr.offset(entries).bitcast[c_void]()
        self.entries = entries
        self.entry_size = entry_size
        self.bgid = bgid

        self_ptr = self[]
        for i in range(entries):
            self_ptr.unsafe_recycle[init=True](index=i)

    @always_inline
    fn unsafe_unregister(owned self, io_uring: IoUring) raises:
        reg = IoUringBufReg(
            ring_addr=0,
            ring_entries=0,
            bgid=self.bgid,
        )
        res = io_uring.register(
            reg.as_register_arg(
                unsafe_opcode=IoUringRegisterOp.UNREGISTER_PBUF_RING
            )
        )
        debug_assert(res == 0, "failed to unregister buffer ring")

    @always_inline
    fn __moveinit__(out self, owned existing: Self):
        """Moves data of an existing BufRing into a new one.

        Args:
            existing: The existing BufRing.
        """
        self._mem = existing._mem^
        self._tail_ptr = existing._tail_ptr
        self._tail = existing._tail
        self._mask = existing._mask
        self._buf_ptr = existing._buf_ptr
        self.entries = existing.entries
        self.entry_size = existing.entry_size
        self.bgid = existing.bgid

    # ===------------------------------------------------------------------===#
    # Operator dunders
    # ===------------------------------------------------------------------===#

    @always_inline
    fn __getitem__(mut self) -> BufRingPtr[__origin_of(self)]:
        """Enable subscript syntax `buf_ring[]` for mutable access to the buffer ring.

        Returns:
            Pointer to the mutable buffer ring.
        """
        return self

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn sync_tail(self):
        _atomic_store(self._tail_ptr, self._tail)

    @always_inline
    @staticmethod
    fn flags_to_index(flags: IoUringCqeFlags) -> UInt16:
        constrained[
            bitwidthof[IoUringCqeFlags]() - IORING_CQE_BUFFER_SHIFT
            <= bitwidthof[UInt16]()
        ]()
        return UInt16((flags >> IORING_CQE_BUFFER_SHIFT).value)


@register_passable
struct BufRingPtr[ring_origin: MutableOrigin]:
    var _ring: Pointer[BufRing, ring_origin]

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @implicit
    @always_inline
    fn __init__(out self, ref [ring_origin]ring: BufRing):
        self._ring = Pointer.address_of(ring)

    @always_inline
    fn __del__(owned self):
        self._ring[].sync_tail()

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn unsafe_buf[
        buf_origin: MutableOrigin
    ](ref [buf_origin]self, *, index: UInt16, len: UInt32) -> Buf[
        buf_origin, ring_origin
    ]:
        buf_ptr = self._ring[]._buf_ptr.offset(
            UInt32(index) * self._ring[].entry_size
        )
        return Buf(
            unsafe_buf_ptr=buf_ptr,
            len=len,
            index=index,
            ring_ptr=Pointer.address_of(self),
        )

    @always_inline
    fn unsafe_buf[
        buf_origin: MutableOrigin
    ](ref [buf_origin]self, *, flags: IoUringCqeFlags, len: UInt32) -> Buf[
        buf_origin, ring_origin
    ]:
        return self.unsafe_buf(index=BufRing.flags_to_index(flags), len=len)

    @always_inline
    fn unsafe_recycle[*, init: Bool = False](mut self, *, index: UInt16):
        next = (
            self._ring[]
            ._mem.unsafe_ptr()
            .bitcast[io_uring_buf]()
            .offset(self._ring[]._tail & self._ring[]._mask)
        )
        next[].addr = Int(
            self._ring[]._buf_ptr.offset(
                UInt32(index) * self._ring[].entry_size
            )
        )

        next[].bid = index

        @parameter
        if init:
            next[].len = self._ring[].entry_size

        self._ring[]._tail += 1

    @always_inline
    fn unsafe_recycle(mut self, *, flags: IoUringCqeFlags):
        self.unsafe_recycle(index=BufRing.flags_to_index(flags))


@register_passable
struct Buf[buf_origin: MutableOrigin, ring_origin: MutableOrigin]:
    var buf_ptr: UnsafePointer[c_void]
    var len: UInt32
    var index: UInt16
    var _ring_ptr: Pointer[BufRingPtr[ring_origin], buf_origin]

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(
        out self,
        *,
        unsafe_buf_ptr: UnsafePointer[c_void],
        len: UInt32,
        index: UInt16,
        ring_ptr: Pointer[BufRingPtr[ring_origin], buf_origin],
    ):
        self.buf_ptr = unsafe_buf_ptr
        self.len = len
        self.index = index
        self._ring_ptr = ring_ptr

    @always_inline
    fn __del__(owned self):
        self._ring_ptr[].unsafe_recycle(index=self.index)

    @always_inline
    fn into_index(owned self) -> UInt16:
        index = self.index
        __disable_del self
        return index
