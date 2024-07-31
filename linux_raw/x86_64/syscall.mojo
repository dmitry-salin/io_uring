from sys._assembly import inlined_assembly
from sys.intrinsics import _mlirtype_is_eq


@always_inline
fn _syscall_constraints[
    args_nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    uses_memory: Bool = True,
]() -> StringLiteral:
    alias has_outputs = not _mlirtype_is_eq[result_type, NoneType]()
    alias outputs = "={rax},={rcx},={r11}," if has_outputs else ""
    alias syscall_nr_reg = "0" if has_outputs else "{rax}"
    alias arg_regs = [",{rdi}", ",{rsi}", ",{rdx}", ",{r10}", ",{r8}", ",{r9}"]
    alias clobbers = ",~{memory}" if uses_memory else ""

    constrained[
        args_nr <= len(arg_regs),
        "the number of arguments must be less than or equal to the maximum",
    ]()

    @parameter
    fn inputs() -> StringLiteral:
        var regs = syscall_nr_reg

        @parameter
        for i in range(args_nr):
            regs = regs + arg_regs.get[i, StringLiteral]()
        return regs

    return outputs + inputs() + clobbers


# ===----------------------------------------------------------------------===#
# 0-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
]() -> result_type:
    """Generates assembly via inline for syscall with 0 args."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            0, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
    )


# ===----------------------------------------------------------------------===#
# 1-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    arg0_type: AnyTrivialRegType, //,
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
](arg0: arg0_type) -> result_type:
    """Generates assembly via inline for syscall with 1 arg."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            1, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
        arg0,
    )


# ===----------------------------------------------------------------------===#
# 2-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    arg0_type: AnyTrivialRegType,
    arg1_type: AnyTrivialRegType, //,
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
](arg0: arg0_type, arg1: arg1_type) -> result_type:
    """Generates assembly via inline for syscall with 2 args."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            2, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
        arg0,
        arg1,
    )


# ===----------------------------------------------------------------------===#
# 3-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    arg0_type: AnyTrivialRegType,
    arg1_type: AnyTrivialRegType,
    arg2_type: AnyTrivialRegType, //,
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
](arg0: arg0_type, arg1: arg1_type, arg2: arg2_type) -> result_type:
    """Generates assembly via inline for syscall with 3 args."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            3, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
        arg0,
        arg1,
        arg2,
    )


# ===----------------------------------------------------------------------===#
# 4-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    arg0_type: AnyTrivialRegType,
    arg1_type: AnyTrivialRegType,
    arg2_type: AnyTrivialRegType,
    arg3_type: AnyTrivialRegType, //,
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
](
    arg0: arg0_type, arg1: arg1_type, arg2: arg2_type, arg3: arg3_type
) -> result_type:
    """Generates assembly via inline for syscall with 4 args."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            4, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
        arg0,
        arg1,
        arg2,
        arg3,
    )


# ===----------------------------------------------------------------------===#
# 5-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    arg0_type: AnyTrivialRegType,
    arg1_type: AnyTrivialRegType,
    arg2_type: AnyTrivialRegType,
    arg3_type: AnyTrivialRegType,
    arg4_type: AnyTrivialRegType, //,
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
](
    arg0: arg0_type,
    arg1: arg1_type,
    arg2: arg2_type,
    arg3: arg3_type,
    arg4: arg4_type,
) -> result_type:
    """Generates assembly via inline for syscall with 5 args."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            5, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
        arg0,
        arg1,
        arg2,
        arg3,
        arg4,
    )


# ===----------------------------------------------------------------------===#
# 6-arg
# ===----------------------------------------------------------------------===#


@always_inline("nodebug")
fn syscall[
    arg0_type: AnyTrivialRegType,
    arg1_type: AnyTrivialRegType,
    arg2_type: AnyTrivialRegType,
    arg3_type: AnyTrivialRegType,
    arg4_type: AnyTrivialRegType,
    arg5_type: AnyTrivialRegType, //,
    nr: IntLiteral,
    result_type: AnyTrivialRegType,
    /,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
](
    arg0: arg0_type,
    arg1: arg1_type,
    arg2: arg2_type,
    arg3: arg3_type,
    arg4: arg4_type,
    arg5: arg5_type,
) -> result_type:
    """Generates assembly via inline for syscall with 6 args."""

    return inlined_assembly[
        "syscall",
        result_type,
        constraints = _syscall_constraints[
            6, result_type, uses_memory=uses_memory
        ](),
        has_side_effect=has_side_effect,
    ](
        nr,
        arg0,
        arg1,
        arg2,
        arg3,
        arg4,
        arg5,
    )
