from .ctypes import c_uint
from linux_raw.x86_64.general import *


@value
@register_passable("trivial")
struct ReadWriteFlags:
    var value: c_uint

    alias HIPRI = c_uint(RWF_HIPRI)
    alias DSYNC = c_uint(RWF_DSYNC)
    alias SYNC = c_uint(RWF_SYNC)
    alias NOWAIT = c_uint(RWF_NOWAIT)
    alias APPEND = c_uint(RWF_APPEND)
