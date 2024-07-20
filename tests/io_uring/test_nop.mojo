from mojix.errno import Errno
from mojix.timespec import Timespec
from io_uring import IoUring, WaitArg
from io_uring.op import Nop
from testing import assert_equal, assert_raises


@value
@register_passable("trivial")
struct OpQueue:
    var size: UInt

    @always_inline
    fn __bool__(self) -> Bool:
        return self.size != 0

    @always_inline
    fn pop(inout self):
        self.size -= 1


fn test_nop() raises:
    var ring = IoUring[](sq_entries=16)
    var queue = OpQueue(128)
    var total = 0

    while queue:
        var to_submit = 0
        var sq = ring.sq()
        while queue and sq:
            _ = Nop(sq.__next__()).user_data(1)
            queue.pop()
            to_submit += 1

        assert_equal(to_submit, 16)
        _ = ring.submit_and_wait(wait_nr=to_submit)
        var completed = 0
        for cqe in ring.cq(wait_nr=0):
            assert_equal(cqe.user_data, 1)
            completed += 1
        assert_equal(completed, to_submit)
        total += to_submit

    assert_equal(total, 128)


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
