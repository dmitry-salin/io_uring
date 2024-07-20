from tests.io_uring.test_nop import test_nop, test_nop_skip_cqe


fn main() raises:
    test_nop()
    test_nop_skip_cqe()
