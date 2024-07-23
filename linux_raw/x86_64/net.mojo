from linux_raw.ctypes import c_ushort, c_uint, c_uchar


alias SOCK_STREAM = 1
alias SOCK_DGRAM = 2
alias SOCK_RAW = 3
alias SOCK_RDM = 4
alias SOCK_SEQPACKET = 5
alias MSG_DONTWAIT = 64
alias AF_UNSPEC = 0
alias AF_UNIX = 1
alias AF_INET = 2
alias AF_AX25 = 3
alias AF_IPX = 4
alias AF_APPLETALK = 5
alias AF_NETROM = 6
alias AF_BRIDGE = 7
alias AF_ATMPVC = 8
alias AF_X25 = 9
alias AF_INET6 = 10
alias AF_ROSE = 11
alias AF_DECnet = 12
alias AF_NETBEUI = 13
alias AF_SECURITY = 14
alias AF_KEY = 15
alias AF_NETLINK = 16
alias AF_PACKET = 17
alias AF_ASH = 18
alias AF_ECONET = 19
alias AF_ATMSVC = 20
alias AF_RDS = 21
alias AF_SNA = 22
alias AF_IRDA = 23
alias AF_PPPOX = 24
alias AF_WANPIPE = 25
alias AF_LLC = 26
alias AF_CAN = 29
alias AF_TIPC = 30
alias AF_BLUETOOTH = 31
alias AF_IUCV = 32
alias AF_RXRPC = 33
alias AF_ISDN = 34
alias AF_PHONET = 35
alias AF_IEEE802154 = 36
alias AF_CAIF = 37
alias AF_ALG = 38
alias AF_NFC = 39
alias AF_VSOCK = 40
alias AF_KCM = 41
alias AF_QIPCRTR = 42
alias AF_SMC = 43
alias AF_XDP = 44
alias AF_MCTP = 45
alias AF_MAX = 46

alias MSG_OOB = 1
alias MSG_PEEK = 2
alias MSG_DONTROUTE = 4
alias MSG_CTRUNC = 8
alias MSG_PROBE = 16
alias MSG_TRUNC = 32
alias MSG_EOR = 128
alias MSG_WAITALL = 256
alias MSG_FIN = 512
alias MSG_SYN = 1024
alias MSG_CONFIRM = 2048
alias MSG_RST = 4096
alias MSG_ERRQUEUE = 8192
alias MSG_NOSIGNAL = 16384
alias MSG_MORE = 32768
alias MSG_CMSG_CLOEXEC = 1073741824

alias IPPROTO_HOPOPTS = 0
alias IPPROTO_ROUTING = 43
alias IPPROTO_FRAGMENT = 44
alias IPPROTO_ICMPV6 = 58
alias IPPROTO_NONE = 59
alias IPPROTO_DSTOPTS = 60
alias IPPROTO_MH = 135

alias IPPROTO_IP = 0
alias IPPROTO_ICMP = 1
alias IPPROTO_IGMP = 2
alias IPPROTO_IPIP = 4
alias IPPROTO_TCP = 6
alias IPPROTO_EGP = 8
alias IPPROTO_PUP = 12
alias IPPROTO_UDP = 17
alias IPPROTO_IDP = 22
alias IPPROTO_TP = 29
alias IPPROTO_DCCP = 33
alias IPPROTO_IPV6 = 41
alias IPPROTO_RSVP = 46
alias IPPROTO_GRE = 47
alias IPPROTO_ESP = 50
alias IPPROTO_AH = 51
alias IPPROTO_MTP = 92
alias IPPROTO_BEETPH = 94
alias IPPROTO_ENCAP = 98
alias IPPROTO_PIM = 103
alias IPPROTO_COMP = 108
alias IPPROTO_L2TP = 115
alias IPPROTO_SCTP = 132
alias IPPROTO_UDPLITE = 136
alias IPPROTO_MPLS = 137
alias IPPROTO_ETHERNET = 143
alias IPPROTO_RAW = 255
alias IPPROTO_MPTCP = 262
alias IPPROTO_MAX = 263

alias __u8 = c_uchar
alias __u16 = c_ushort
alias __u32 = c_uint

alias __be16 = __u16
alias __be32 = __u32

alias socklen_t = c_uint

alias __kernel_sa_family_t = c_ushort


@value
@register_passable("trivial")
struct in_addr:
    var s_addr: __be32


@value
struct sockaddr_in:
    var sin_family: __kernel_sa_family_t
    var sin_port: __be16
    var sin_addr: in_addr
    var __pad: InlineArray[c_uchar, 8]


@value
struct in6_addr:
    var in6_u: InlineArray[__u8, 16]


@value
struct sockaddr_in6:
    var sin6_family: c_ushort
    var sin6_port: __be16
    var sin6_flowinfo: __be32
    var sin6_addr: in6_addr
    var sin6_scope_id: __u32
