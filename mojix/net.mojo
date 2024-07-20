from linux_raw.x86_64.net import *


@value
@register_passable("trivial")
struct SendFlags:
    """`MSG_*` flags for use with `send`, `send_to`, and related functions."""

    alias CONFIRM = Self(MSG_CONFIRM)
    alias DONTROUTE = Self(MSG_DONTROUTE)
    alias DONTWAIT = Self(MSG_DONTWAIT)
    alias EOR = Self(MSG_EOR)
    alias MORE = Self(MSG_MORE)
    alias NOSIGNAL = Self(MSG_NOSIGNAL)
    alias OOB = Self(MSG_OOB)

    var value: UInt32


@value
@register_passable("trivial")
struct RecvFlags:
    """`MSG_*` flags for use with `recv`, `recvfrom`, and related functions."""

    alias CMSG_CLOEXEC = Self(MSG_CMSG_CLOEXEC)
    alias DONTWAIT = Self(MSG_DONTWAIT)
    alias ERRQUEUE = Self(MSG_ERRQUEUE)
    alias OOB = Self(MSG_OOB)
    alias PEEK = Self(MSG_PEEK)
    alias TRUNC = Self(MSG_TRUNC)
    alias WAITALL = Self(MSG_WAITALL)

    var value: UInt32
