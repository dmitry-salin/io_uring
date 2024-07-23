from bit import byte_swap
from sys.info import is_big_endian


@always_inline("nodebug")
fn _aligned_u64[T: AnyType]():
    # [Linux]: https://github.com/torvalds/linux/blob/v6.7/include/uapi/linux/types.h#L47.
    constrained[alignof[T]() >= 8]()


@always_inline("nodebug")
fn _size_eq[T: AnyType, I: AnyType]():
    constrained[sizeof[T]() == sizeof[I]()]()


@always_inline("nodebug")
fn _size_eq[T: AnyType, size: IntLiteral]():
    constrained[sizeof[T]() == size]()


@always_inline("nodebug")
fn _align_eq[T: AnyType, align: IntLiteral]():
    constrained[alignof[T]() == align]()


@always_inline("nodebug")
fn _to_be[
    type: DType, simd_width: Int
](value: SIMD[type, simd_width]) -> SIMD[type, simd_width]:
    @parameter
    if is_big_endian():
        return value
    else:
        return byte_swap(value)
