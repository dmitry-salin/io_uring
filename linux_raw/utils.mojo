from sys import has_neon
from sys.info import is_x86, is_64bit


@always_inline("nodebug")
fn is_x86_64() -> Bool:
    return is_x86() and is_64bit()


@value
struct DTypeArray[
    dtype: DType,
    size: Int,
](Sized, Movable, Copyable, ExplicitlyCopyable, Defaultable):
    """A fixed size sequence of DType elements.

    Parameters:
        dtype: The type of the elements in the array.
        size: The size of the array.
    """

    alias type = __mlir_type[
        `!pop.array<`, size.value, `, `, Scalar[dtype], `>`
    ]

    var array: Self.type
    """The underlying storage for the array."""

    # ===------------------------------------------------------------------===#
    # Life cycle methods
    # ===------------------------------------------------------------------===#

    @always_inline
    fn __init__(inout self):
        """Constructs a default DTypeArray."""
        Self._is_valid()
        zero = Scalar[dtype](
            __mlir_op.`pop.cast`[
                _type = __mlir_type[`!pop.simd<1,`, dtype.value, `>`]
            ](
                __mlir_op.`kgen.param.constant`[
                    _type = __mlir_type[`!pop.scalar<index>`],
                    value = __mlir_attr[`#pop.simd<0> : !pop.scalar<index>`],
                ]()
            )
        )
        self.array = __mlir_op.`pop.array.repeat`[_type = Self.type](zero)

    @always_inline
    fn __init__(inout self, *, unsafe_uninitialized: Bool):
        """Constructs a DTypeArray with uninitialized memory.
        Note that this is highly unsafe and should be used with caution.

        Args:
            unsafe_uninitialized: A boolean to indicate if the array
                should be initialized. Always set to `True`
                (it's not actually used inside the constructor).
        """
        self.array = __mlir_op.`kgen.undef`[_type = Self.type]()

    @always_inline
    fn __init__(inout self, fill: Scalar[dtype]):
        """Constructs a DTypeArray where each element is the supplied `fill`.

        Args:
            fill: The element to fill each index.
        """
        Self._is_valid()
        self.array = __mlir_op.`pop.array.repeat`[_type = Self.type](fill)

    @always_inline
    fn __init__(inout self, *, other: Self):
        """Explicitly copy constructs a DTypeArray.

        Args:
            other: The DTypeArray to copy.
        """
        self.array = other.array

    @always_inline("nodebug")
    @staticmethod
    fn _non_zero_size():
        constrained[
            size > 0,
            "the number of elements in an initialized `DTypeArray` must be > 0",
        ]()

    @always_inline("nodebug")
    @staticmethod
    fn _is_valid():
        Self._non_zero_size()
        constrained[
            dtype is not DType.invalid, "dtype cannot be DType.invalid"
        ]()
        constrained[
            dtype is not DType.bfloat16 or not has_neon(),
            "bf16 is not supported for ARM architectures",
        ]()

    # ===------------------------------------------------------------------===#
    # Operator dunders
    # ===------------------------------------------------------------------===#

    @always_inline("nodebug")
    fn __getitem__[idx: UInt](self: Self) -> Scalar[dtype]:
        """Get the element at the given index.

        Parameters:
            idx: The index of the element.

        Returns:
            The element at the given index.
        """
        Self._non_zero_size()
        constrained[idx < size, "index must be within bounds"]()

        return __mlir_op.`pop.array.get`[
            _type = Scalar[dtype],
            index = idx.value,
        ](self.array)

    @always_inline("nodebug")
    fn __getitem__(self: Self, idx: UInt) -> Scalar[dtype]:
        """Get the element at the given index.

        Args:
            idx: The index of the element.

        Returns:
            The element at the given index.
        """
        Self._non_zero_size()
        debug_assert(idx < size, "index must be within bounds")
        ptr = __mlir_op.`pop.array.gep`(
            UnsafePointer.address_of(self.array).address,
            idx.value,
        )
        return UnsafePointer(ptr)[]

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        """Returns the length of the array. This is a known constant value.

        Returns:
            The size of the array.
        """
        return size
