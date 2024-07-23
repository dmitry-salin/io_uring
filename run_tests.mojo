from tests.io_uring.test_nop import test_nop, test_nop_skip_cqe
from tests.io_uring.test_net import test_accept_timeout


fn main() raises:
    test_nop()
    test_nop_skip_cqe()
    test_accept_timeout()
