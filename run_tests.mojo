from mojix.errno import Errno
from mojix.timespec import Timespec
from io_uring import IoUring, WaitArg
from testing import assert_equal, assert_raises


fn test_nop_skip_cqe() raises:
    var ring = IoUring[](sq_entries=8)
    var count = 0
    for _sqe in ring.sq():
        count += 1
    assert_equal(count, 8)

    var submitted = ring.submit_and_wait(wait_nr=0)
    assert_equal(submitted, 8)

    var ts = Timespec(tv_sec=0, tv_nsec=100000000)
    # We expect a timeout and 0 cqes because none of the submitted sqes were
    # configured to perform any operation.
    with assert_raises(contains=str(Errno.ETIME)):
        _ = ring.cq(wait_nr=1, arg=WaitArg(ts).as_enter_arg())


fn main() raises:
    test_nop_skip_cqe()
