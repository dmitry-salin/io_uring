from linux_raw.ctypes import c_ulong, c_longlong

alias __NR_close = 3
alias __NR_mmap = 9
alias __NR_munmap = 11
alias __NR_madvise = 28
alias __NR_io_uring_setup = 425
alias __NR_io_uring_enter = 426
alias __NR_io_uring_register = 427

alias PROT_READ = 1
alias PROT_WRITE = 2
alias PROT_EXEC = 4
alias PROT_SEM = 8
alias PROT_NONE = 0
alias PROT_GROWSDOWN = 16777216
alias PROT_GROWSUP = 33554432

alias MAP_TYPE = 15
alias MAP_FIXED = 16
alias MAP_ANONYMOUS = 32
alias MAP_POPULATE = 32768
alias MAP_NONBLOCK = 65536
alias MAP_STACK = 131072
alias MAP_HUGETLB = 262144
alias MAP_SYNC = 524288
alias MAP_FIXED_NOREPLACE = 1048576
alias MAP_UNINITIALIZED = 67108864

alias MADV_NORMAL = 0
alias MADV_RANDOM = 1
alias MADV_SEQUENTIAL = 2
alias MADV_WILLNEED = 3
alias MADV_DONTNEED = 4
alias MADV_FREE = 8
alias MADV_REMOVE = 9
alias MADV_DONTFORK = 10
alias MADV_DOFORK = 11
alias MADV_HWPOISON = 100
alias MADV_SOFT_OFFLINE = 101
alias MADV_MERGEABLE = 12
alias MADV_UNMERGEABLE = 13
alias MADV_HUGEPAGE = 14
alias MADV_NOHUGEPAGE = 15
alias MADV_DONTDUMP = 16
alias MADV_DODUMP = 17
alias MADV_WIPEONFORK = 18
alias MADV_KEEPONFORK = 19
alias MADV_COLD = 20
alias MADV_PAGEOUT = 21
alias MADV_POPULATE_READ = 22
alias MADV_POPULATE_WRITE = 23
alias MADV_DONTNEED_LOCKED = 24
alias MADV_COLLAPSE = 25

alias MAP_FILE = 0
alias PKEY_DISABLE_ACCESS = 1
alias PKEY_DISABLE_WRITE = 2
alias PKEY_ACCESS_MASK = 3
alias MAP_GROWSDOWN = 256
alias MAP_DENYWRITE = 2048
alias MAP_EXECUTABLE = 4096
alias MAP_LOCKED = 8192
alias MAP_NORESERVE = 16384

alias MAP_SHARED = 1
alias MAP_PRIVATE = 2
alias MAP_SHARED_VALIDATE = 3
alias MAP_HUGE_SHIFT = 26
alias MAP_HUGE_MASK = 63
alias MAP_HUGE_16KB = 939524096
alias MAP_HUGE_64KB = 1073741824
alias MAP_HUGE_512KB = 1275068416
alias MAP_HUGE_1MB = 1342177280
alias MAP_HUGE_2MB = 1409286144
alias MAP_HUGE_8MB = 1543503872
alias MAP_HUGE_16MB = 1610612736
alias MAP_HUGE_32MB = 1677721600
alias MAP_HUGE_256MB = 1879048192
alias MAP_HUGE_512MB = 1946157056
alias MAP_HUGE_1GB = 2013265920
alias MAP_HUGE_2GB = 2080374784
alias MAP_HUGE_16GB = 2281701376

alias RWF_HIPRI = 1
alias RWF_DSYNC = 2
alias RWF_SYNC = 4
alias RWF_NOWAIT = 8
alias RWF_APPEND = 16


@value
@register_passable("trivial")
struct __kernel_timespec:
    var tv_sec: c_longlong
    var tv_nsec: c_longlong


alias sigset_t = c_ulong
