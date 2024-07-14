# Currently only x86-64 platform is supported.

# The signedness of `char` is platform-specific.
alias c_char = c_schar

# The following assumes that Linux is always either ILP32 or LP64,
# and char is always 8-bit.
#
# In theory, `c_long` and `c_ulong` could be `Int` and `UInt`
# respectively, however in practice Linux doesn't use them in that way
# consistently. So stick with the convention followed by `libc` and
# others and use the fixed-width types.

alias c_schar = Int8
alias c_uchar = UInt8
alias c_short = Int16
alias c_ushort = UInt16
alias c_int = Int32
alias c_uint = UInt32
alias c_long = Int64
alias c_ulong = UInt64
alias c_longlong = Int64
alias c_ulonglong = UInt64
alias c_float = Float32
alias c_double = Float64

alias c_void = Int8
