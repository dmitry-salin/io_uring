from sys.info import is_x86, is_64bit


@always_inline("nodebug")
fn is_x86_64() -> Bool:
    return is_x86() and is_64bit()
