@always_inline("nodebug")
fn _aligned_u64[T: AnyType]():
    # [Linux]: https://github.com/torvalds/linux/blob/v6.7/include/uapi/linux/types.h#L47.
    constrained[alignof[T]() >= 8]()
