from mojix.errno import Errno
from mojix.timespec import Timespec
from io_uring import IoUring, WaitArg
from io_uring.op import Nop


@value
@register_passable("trivial")
struct OpQueue:
    var size: UInt

    @always_inline
    fn __bool__(self) -> Bool:
        return self.size != 0

    @always_inline
    fn pop(mut self):
        self.size -= 1


fn main() raises:
    ring = IoUring[](sq_entries=16)
    queue = OpQueue(128)
    total = 0

    while queue:
        to_submit = 0
        sq = ring.sq()
        while queue and sq:
            _ = Nop(sq.__next__()).user_data(1)
            queue.pop()
            to_submit += 1
            print("[Queue] Preparing to submit operation:", to_submit, "remaining in queue:", queue.size)

        _ = ring.submit_and_wait(wait_nr=to_submit)
        completed = 0
        for cqe in ring.cq(wait_nr=0):
            print("[Completion] Completed operation with result code:", cqe.res)
            completed += 1
        total += to_submit
    print("[Summary] Total operations processed:", total)
