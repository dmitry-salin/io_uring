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
from linux_raw.utils import DTypeArray
from sys.info import alignof, sizeof
from memory import UnsafePointer


alias SOCK_CLOEXEC = O_CLOEXEC
alias SOCK_NONBLOCK = O_NONBLOCK

alias Backlog = c_uint


trait SocketAddr(Defaultable):
    alias ADDR_LEN: socklen_t

    fn addr_unsafe_ptr(ref self) -> UnsafePointer[c_void]:
        ...


trait SocketAddrMut(Defaultable):
    fn addr_unsafe_ptr(ref self) -> UnsafePointer[c_void]:
        ...

    fn len_unsafe_ptr(ref self) -> UnsafePointer[c_void]:
        ...


trait SocketAddrStor:
    alias SocketAddrStor: SocketAddr

    fn addr_stor(ref self, out result: SocketAddrStor):
        ...


trait SocketAddrStorMut:
    alias SocketAddrStorMut: SocketAddrMut

    @staticmethod
    fn addr_stor_mut(out result: SocketAddrStorMut):
        ...


@value
@register_passable("trivial")
struct SocketAddrStorV4(SocketAddr):
    alias ADDR_LEN: socklen_t = sizeof[sockaddr_in]()

    var addr: sockaddr_in

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(out self):
        _size_eq[Self, 16]()
        _align_eq[Self, 4]()
        self.addr = sockaddr_in(
            0, 0, in_addr(0), DTypeArray[c_uchar.element_type, 8]()
        )

    @always_inline
    fn __init__[
        origin: ImmutableOrigin
    ](out self, ref [origin]addr: SocketAddrV4):
        _size_eq[Self, 16]()
        _align_eq[Self, 4]()
        _size_eq[addr.Octets, __be32]()
        _align_eq[addr.Octets, __be32]()

        self.addr = sockaddr_in(
            AddrFamily.INET.id,
            _to_be(addr.port),
            in_addr(
                UnsafePointer.address_of(addr.octets())
                .bitcast[__be32]()
                .load[alignment = alignof[addr.Octets]()]()
            ),
            DTypeArray[c_uchar.element_type, 8](),
        )

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn addr_unsafe_ptr(ref self) -> UnsafePointer[c_void]:
        return UnsafePointer.address_of(self.addr).bitcast[c_void]()


alias SocketAddrStorMutV4 = SocketAddrStorAnyMut[SocketAddrStorV4]


struct SocketAddrStorAnyMut[Addr: SocketAddr](SocketAddrMut):
    var addr: Addr
    var len: socklen_t

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(out self):
        self.addr = Addr()
        self.len = Addr.ADDR_LEN

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn addr_unsafe_ptr(ref self) -> UnsafePointer[c_void]:
        return self.addr.addr_unsafe_ptr()

    @always_inline
    fn len_unsafe_ptr(ref self) -> UnsafePointer[c_void]:
        return UnsafePointer.address_of(self.len).bitcast[c_void]()


@value
@register_passable("trivial")
struct IpAddrV4:
    alias Octets = SIMD[DType.uint8, 4]

    var octets: Self.Octets

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(out self, a: UInt8, b: UInt8, c: UInt8, d: UInt8):
        self.octets = Self.Octets(a, b, c, d)


@value
@register_passable("trivial")
struct SocketAddrV4(SocketAddrStor, SocketAddrStorMut):
    alias SocketAddrStor: SocketAddr = SocketAddrStorV4
    alias SocketAddrStorMut: SocketAddrMut = SocketAddrStorMutV4
    alias Octets = IpAddrV4.Octets

    var ip: IpAddrV4
    var port: UInt16

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __init__(
        out self, a: UInt8, b: UInt8, c: UInt8, d: UInt8, *, port: UInt16
    ):
        self.ip = IpAddrV4(a, b, c, d)
        self.port = port

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn octets(ref self) -> ref [self.ip.octets] Self.Octets:
        return self.ip.octets

    # ===------------------------------------------------------------------=== #
    # Trait implementations
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn addr_stor(ref self, out result: Self.SocketAddrStor):
        result = Self.SocketAddrStor(self)

    @staticmethod
    @always_inline
    fn addr_stor_mut(out result: Self.SocketAddrStorMut):
        result = Self.SocketAddrStorMut()


alias RawSocketType = c_uint


@value
@register_passable("trivial")
struct SocketType:
    """`SOCK_*` constants for use with `socket`."""

    alias STREAM = Self(unsafe_id=SOCK_STREAM)
    alias DGRAM = Self(unsafe_id=SOCK_DGRAM)
    alias SEQPACKET = Self(unsafe_id=SOCK_SEQPACKET)
    alias RAW = Self(unsafe_id=SOCK_RAW)
    alias RDM = Self(unsafe_id=SOCK_RDM)

    var id: RawSocketType

    @always_inline("nodebug")
    fn __init__(out self, *, unsafe_id: RawSocketType):
        self.id = unsafe_id


@value
@register_passable("trivial")
struct SocketFlags(Defaultable):
    """`SOCK_*` constants for use with `socket`."""

    alias NONBLOCK = Self(SOCK_NONBLOCK)
    alias CLOEXEC = Self(SOCK_CLOEXEC)

    var value: c_uint

    @always_inline("nodebug")
    fn __init__(out self):
        self.value = 0

    @always_inline("nodebug")
    @implicit
    fn __init__(out self, value: c_uint):
        self.value = value

    @always_inline("nodebug")
    fn __or__(self, rhs: Self) -> Self:
        """Returns `self | rhs`.

        Args:
            rhs: The RHS value.

        Returns:
            `self | rhs`.
        """
        return self.value | rhs.value


alias RawAddrFamily = __kernel_sa_family_t


@value
@register_passable("trivial")
struct AddrFamily:
    """`AF_*` constants for use with `socket`."""

    alias UNSPEC = Self(unsafe_id=AF_UNSPEC)
    alias INET = Self(unsafe_id=AF_INET)
    alias INET6 = Self(unsafe_id=AF_INET6)
    alias NETLINK = Self(unsafe_id=AF_NETLINK)
    alias UNIX = Self(unsafe_id=AF_UNIX)

    var id: RawAddrFamily

    @always_inline("nodebug")
    fn __init__(out self, *, unsafe_id: RawAddrFamily):
        self.id = unsafe_id


@value
@register_passable("trivial")
struct Protocol(Defaultable):
    """`IPPROTO_*` and other constants for use with `socket`."""

    alias IP = Self(unsafe_id=IPPROTO_IP)
    alias ICMP = Self(unsafe_id=IPPROTO_ICMP)
    alias IGMP = Self(unsafe_id=IPPROTO_IGMP)
    alias IPIP = Self(unsafe_id=IPPROTO_IPIP)
    alias TCP = Self(unsafe_id=IPPROTO_TCP)
    alias EGP = Self(unsafe_id=IPPROTO_EGP)
    alias PUP = Self(unsafe_id=IPPROTO_PUP)
    alias UDP = Self(unsafe_id=IPPROTO_UDP)
    alias IDP = Self(unsafe_id=IPPROTO_IDP)
    alias TP = Self(unsafe_id=IPPROTO_TP)
    alias DCCP = Self(unsafe_id=IPPROTO_DCCP)
    alias IPV6 = Self(unsafe_id=IPPROTO_IPV6)
    alias RSVP = Self(unsafe_id=IPPROTO_RSVP)
    alias GRE = Self(unsafe_id=IPPROTO_GRE)
    alias ESP = Self(unsafe_id=IPPROTO_ESP)
    alias AH = Self(unsafe_id=IPPROTO_AH)
    alias MTP = Self(unsafe_id=IPPROTO_MTP)
    alias BEETPH = Self(unsafe_id=IPPROTO_BEETPH)
    alias ENCAP = Self(unsafe_id=IPPROTO_ENCAP)
    alias PIM = Self(unsafe_id=IPPROTO_PIM)
    alias COMP = Self(unsafe_id=IPPROTO_COMP)
    alias SCTP = Self(unsafe_id=IPPROTO_SCTP)
    alias UDPLITE = Self(unsafe_id=IPPROTO_UDPLITE)
    alias MPLS = Self(unsafe_id=IPPROTO_MPLS)
    alias ETHERNET = Self(unsafe_id=IPPROTO_ETHERNET)
    alias RAW = Self(unsafe_id=IPPROTO_RAW)
    alias MPTCP = Self(unsafe_id=IPPROTO_MPTCP)
    alias FRAGMENT = Self(unsafe_id=IPPROTO_FRAGMENT)
    alias ICMPV6 = Self(unsafe_id=IPPROTO_ICMPV6)
    alias MH = Self(unsafe_id=IPPROTO_MH)
    alias ROUTING = Self(unsafe_id=IPPROTO_ROUTING)

    var id: c_uint

    @always_inline("nodebug")
    fn __init__(out self):
        constrained[IPPROTO_IP == 0]()
        self = Self(unsafe_id=IPPROTO_IP)

    @always_inline("nodebug")
    fn __init__(out self, *, unsafe_id: c_uint):
        self.id = unsafe_id


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

    var value: c_uint


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

    var value: c_uint
