from linux_raw.x86_64.net import *


@value
@register_passable("trivial")
struct SendFlags:
    var value: UInt32

    alias CONFIRM = UInt32(MSG_CONFIRM)
    alias DONTROUTE = UInt32(MSG_DONTROUTE)
    alias DONTWAIT = UInt32(MSG_DONTWAIT)
    alias EOR = UInt32(MSG_EOR)
    alias MORE = UInt32(MSG_MORE)
    alias NOSIGNAL = UInt32(MSG_NOSIGNAL)
    alias OOB = UInt32(MSG_OOB)


@value
@register_passable("trivial")
struct RecvFlags:
    var value: UInt32

    alias CMSG_CLOEXEC = UInt32(MSG_CMSG_CLOEXEC)
    alias DONTWAIT = UInt32(MSG_DONTWAIT)
    alias ERRQUEUE = UInt32(MSG_ERRQUEUE)
    alias OOB = UInt32(MSG_OOB)
    alias PEEK = UInt32(MSG_PEEK)
    alias TRUNC = UInt32(MSG_TRUNC)
    alias WAITALL = UInt32(MSG_WAITALL)
