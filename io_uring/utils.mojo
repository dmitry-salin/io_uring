from sys.intrinsics import _RegisterPackType, llvm_intrinsic
from sys.info import bitwidthof
from memory import UnsafePointer

@value
@nonmaterializable(NoneType)
@register_passable("trivial")
struct AtomicOrdering:
    alias ACQUIRE = Self(id=0)
    alias RELEASE = Self(id=1)
    alias RELAXED = Self(id=2)

    var id: UInt8
    
    @always_inline("nodebug")
    fn __is__(self, rhs: Self) -> Bool:
        """Defines whether one AtomicOrdering has the same identity as another.

        Args:
            rhs: The AtomicOrdering to compare against.

        Returns:
            True if theAtomicOrderings have the same identity, False otherwise.
        """
       return self.id == rhs.id


@always_inline("nodebug")
fn _atomic_load[
    ordering: AtomicOrdering
](unsafe_ptr: UnsafePointer[UInt32]) -> UInt32:
    addr = unsafe_ptr.bitcast[
        __mlir_type[`!pop.scalar<`, DType.uint32.value, `>`]
    ]().address

    # TODO: use atomic load when it becomes available.
    @parameter
    if ordering is AtomicOrdering.ACQUIRE:
        return __mlir_op.`pop.atomic.rmw`[
            bin_op = __mlir_attr.`#pop<bin_op add>`,
            ordering = __mlir_attr.`#pop<atomic_ordering acquire>`,
            _type = __mlir_type[`!pop.scalar<`, DType.uint32.value, `>`],
        ](
            addr,
            UInt32(0).value,
        )
    elif ordering is AtomicOrdering.RELAXED:
        return __mlir_op.`pop.atomic.rmw`[
            bin_op = __mlir_attr.`#pop<bin_op add>`,
            ordering = __mlir_attr.`#pop<atomic_ordering monotonic>`,
            _type = __mlir_type[`!pop.scalar<`, DType.uint32.value, `>`],
        ](
            addr,
            UInt32(0).value,
        )
    else:
        constrained[False, "unsupported atomic ordering"]()
        return unsafe_ptr[]


@always_inline("nodebug")
fn _atomic_store(unsafe_ptr: UnsafePointer[UInt32], rhs: UInt32):
    # TODO: use atomic store when it becomes available.
    _ = __mlir_op.`pop.atomic.rmw`[
        bin_op = __mlir_attr.`#pop<bin_op xchg>`,
        ordering = __mlir_attr.`#pop<atomic_ordering release>`,
        _type = __mlir_type[`!pop.scalar<`, DType.uint32.value, `>`],
    ](
        unsafe_ptr.bitcast[
            __mlir_type[`!pop.scalar<`, DType.uint32.value, `>`]
        ]().address,
        rhs.value,
    )


@always_inline("nodebug")
fn _next_power_of_two(value: UInt32) -> UInt32:
    """Returns the smallest power of two greater than or equal
    to the input value.

    When the return value overflows, function panics if assertions are enabled,
    and the return value wraps to 0 otherwise (the only situation in which
    function can return 0).

    Args:
        value: The input value.

    Returns:
        The smallest power of two greater than or equal to the input value.
    """
    debug_assert(value <= (1 << (bitwidthof[UInt32]() - 1)), "result overflow")
    return _one_less_than_next_power_of_two(value) + 1


@always_inline("nodebug")
fn _one_less_than_next_power_of_two(value: UInt32) -> UInt32:
    """Returns one less than the next power of two.

    Args:
        value: The input value.

    Returns:
        One less than the next power of two of the input value.

    This function cannot overflow, as in the `_next_power_of_two`
    overflow cases it instead ends up returning the maximum value
    of the type, and can return 0 for 0.
    """
    if value <= 1:
        return 0

    p = value - 1
    # Because `p > 0`, it cannot consist entirely of leading zeros.
    # That means the shift is always in-bounds, and some processors
    # (such as Intel pre-Haswell) have more efficient ctlz
    # intrinsics when the argument is non-zero.
    z = llvm_intrinsic["llvm.ctlz", UInt32, has_side_effect=False](p, True)
    return UInt32.MAX >> z

@always_inline("nodebug")
fn _add_with_overflow(lhs: UInt32, rhs: UInt32) -> (UInt32, Bool):
    """Computes `lhs + rhs` and a `Bool` indicating overflow.
    Args:
        lhs: The lhs value.
        rhs: The rhs value.
    Returns:
        A tuple with the results of the operation and a `Bool` indicating
        overflow.
    """
    res = llvm_intrinsic[
        "llvm.uadd.with.overflow",
        _RegisterPackType[UInt32, Bool],
    ](lhs, rhs)
    return (res[0], res[1])
