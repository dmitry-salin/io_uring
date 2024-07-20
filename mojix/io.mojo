from .ctypes import c_uint
from linux_raw.x86_64.general import *


@value
@register_passable("trivial")
struct ReadWriteFlags:
    """`RWF_*` constants for use with `preadv2` and `pwritev2`."""

    alias HIPRI = Self(RWF_HIPRI)
    alias DSYNC = Self(RWF_DSYNC)
    alias SYNC = Self(RWF_SYNC)
    alias NOWAIT = Self(RWF_NOWAIT)
    alias APPEND = Self(RWF_APPEND)

    var value: c_uint
