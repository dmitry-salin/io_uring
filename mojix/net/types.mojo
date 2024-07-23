from mojix.ctypes import c_void
from mojix.utils import _to_be, _size_eq, _align_eq
from linux_raw.x86_64.general import O_CLOEXEC, O_NONBLOCK
from linux_raw.x86_64.net import (
    __kernel_sa_family_t,
    __be32,
    sockaddr_in,
    socklen_t,
    in_addr,
)
from linux_raw.x86_64.net import *


alias SOCK_CLOEXEC = O_CLOEXEC
alias SOCK_NONBLOCK = O_NONBLOCK

alias Backlog = c_uint


trait SocketAddress(Defaultable):
    fn addr_unsafe_ptr(self) -> UnsafePointer[c_void]:
        ...

    # TODO: Convert to an alias associated with the trait.
    fn addr_len(self) -> socklen_t:
        ...


trait SocketAddressMutable(Defaultable):
    fn addr_unsafe_ptr(self) -> UnsafePointer[c_void]:
        ...

    fn addr_len_unsafe_ptr(self) -> UnsafePointer[c_void]:
        ...


@value
struct SocketAddressArgV4(SocketAddress):
    var addr: sockaddr_in

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self):
        _size_eq[sockaddr_in, 16]()
        _align_eq[sockaddr_in, 4]()
        self.addr = sockaddr_in(0, 0, in_addr(0), InlineArray[c_uchar, 8](0))

    @always_inline("nodebug")
    fn __init__(inout self, addr: SocketAddressV4):
        _size_eq[sockaddr_in, 16]()
        _align_eq[sockaddr_in, 4]()
        _size_eq[addr.Octets, __be32]()

        self.addr = sockaddr_in(
            AddressFamily.INET.id,
            _to_be(addr.port),
            in_addr(
                __be32.load[alignment = alignof[addr.Octets]()](
                    addr.octets().unsafe_ptr().bitcast[__be32](), 0
                )
            ),
            InlineArray[c_uchar, 8](0),
        )

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn addr_unsafe_ptr(self) -> UnsafePointer[c_void]:
        return UnsafePointer.address_of(self.addr).bitcast[c_void]()

    @always_inline("nodebug")
    fn addr_len(self) -> socklen_t:
        return sizeof[sockaddr_in]()


struct SocketAddressArgMut[Addr: SocketAddress](SocketAddressMutable):
    var addr: Addr
    var len: socklen_t

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self):
        self.addr = Addr()
        self.len = self.addr.addr_len()

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn addr_unsafe_ptr(self) -> UnsafePointer[c_void]:
        return self.addr.addr_unsafe_ptr()

    @always_inline("nodebug")
    fn addr_len_unsafe_ptr(self) -> UnsafePointer[c_void]:
        return UnsafePointer.address_of(self.len).bitcast[c_void]()


@value
struct IpAddressV4:
    alias Octets = InlineArray[UInt8, 4]

    var octets: Self.Octets

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(inout self, a: UInt8, b: UInt8, c: UInt8, d: UInt8):
        self.octets = Self.Octets(a, b, c, d)


@value
struct SocketAddressV4:
    alias Octets = IpAddressV4.Octets
    alias Arg = SocketAddressArgV4
    alias ArgMut = SocketAddressArgMut[Self.Arg]

    var ip: IpAddressV4
    var port: UInt16

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline("nodebug")
    fn __init__(
        inout self, a: UInt8, b: UInt8, c: UInt8, d: UInt8, *, port: UInt16
    ):
        self.ip = IpAddressV4(a, b, c, d)
        self.port = port

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline("nodebug")
    fn octets(self) -> ref [__lifetime_of(self)] Self.Octets:
        return self.ip.octets


alias RawSocketType = UInt32


@value
@register_passable("trivial")
struct SocketType:
    """`SOCK_*` constants for use with `socket`."""

    alias STREAM = Self {id: SOCK_STREAM}
    alias DGRAM = Self {id: SOCK_DGRAM}
    alias SEQPACKET = Self {id: SOCK_SEQPACKET}
    alias RAW = Self {id: SOCK_RAW}
    alias RDM = Self {id: SOCK_RDM}

    var id: RawSocketType


@value
@register_passable("trivial")
struct SocketFlags(Defaultable):
    """`SOCK_*` constants for use with `socket`."""

    alias NONBLOCK = Self(SOCK_NONBLOCK)
    alias CLOEXEC = Self(SOCK_CLOEXEC)

    var value: c_uint

    @always_inline("nodebug")
    fn __init__(inout self):
        self.value = 0

    @always_inline("nodebug")
    fn __or__(self, rhs: Self) -> Self:
        """Returns `self | rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self | rhs`.
        """
        return self.value | rhs.value


alias RawAddressFamily = __kernel_sa_family_t


@value
@register_passable("trivial")
struct AddressFamily:
    """`AF_*` constants for use with `socket`."""

    alias UNSPEC = Self {id: AF_UNSPEC}
    alias INET = Self {id: AF_INET}
    alias INET6 = Self {id: AF_INET6}
    alias NETLINK = Self {id: AF_NETLINK}
    alias UNIX = Self {id: AF_UNIX}

    var id: RawAddressFamily


@value
@register_passable("trivial")
struct Protocol(Defaultable):
    """`IPPROTO_*` and other constants for use with `socket`."""

    alias IP = Self {id: IPPROTO_IP}
    alias ICMP = Self {id: IPPROTO_ICMP}
    alias IGMP = Self {id: IPPROTO_IGMP}
    alias IPIP = Self {id: IPPROTO_IPIP}
    alias TCP = Self {id: IPPROTO_TCP}
    alias EGP = Self {id: IPPROTO_EGP}
    alias PUP = Self {id: IPPROTO_PUP}
    alias UDP = Self {id: IPPROTO_UDP}
    alias IDP = Self {id: IPPROTO_IDP}
    alias TP = Self {id: IPPROTO_TP}
    alias DCCP = Self {id: IPPROTO_DCCP}
    alias IPV6 = Self {id: IPPROTO_IPV6}
    alias RSVP = Self {id: IPPROTO_RSVP}
    alias GRE = Self {id: IPPROTO_GRE}
    alias ESP = Self {id: IPPROTO_ESP}
    alias AH = Self {id: IPPROTO_AH}
    alias MTP = Self {id: IPPROTO_MTP}
    alias BEETPH = Self {id: IPPROTO_BEETPH}
    alias ENCAP = Self {id: IPPROTO_ENCAP}
    alias PIM = Self {id: IPPROTO_PIM}
    alias COMP = Self {id: IPPROTO_COMP}
    alias SCTP = Self {id: IPPROTO_SCTP}
    alias UDPLITE = Self {id: IPPROTO_UDPLITE}
    alias MPLS = Self {id: IPPROTO_MPLS}
    alias ETHERNET = Self {id: IPPROTO_ETHERNET}
    alias RAW = Self {id: IPPROTO_RAW}
    alias MPTCP = Self {id: IPPROTO_MPTCP}
    alias FRAGMENT = Self {id: IPPROTO_FRAGMENT}
    alias ICMPV6 = Self {id: IPPROTO_ICMPV6}
    alias MH = Self {id: IPPROTO_MH}
    alias ROUTING = Self {id: IPPROTO_ROUTING}

    var id: UInt32

    @always_inline("nodebug")
    fn __init__(inout self):
        constrained[Self.IP.id == 0]()
        self.id = 0


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
