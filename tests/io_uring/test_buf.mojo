from mojix.io_uring import IoUringCqeFlags
from io_uring import IoUring
from io_uring.buf import BufRing
from testing import assert_equal


fn test_flags_to_index() raises:
    flags = IoUringCqeFlags(2298576896)
    index = BufRing.flags_to_index(flags)
    assert_equal(index, 35073)


fn test_buf_into_index() raises:
    ring = IoUring[](sq_entries=16)
    buf_ring = ring.create_buf_ring(bgid=0, entries=128, entry_size=1024)
    assert_equal(buf_ring._tail, 128)

    buf_ring_ptr = buf_ring[]
    buf = buf_ring_ptr.unsafe_buf(flags=IoUringCqeFlags(0), len=1024)
    index = buf^.into_index()
    assert_equal(index, 0)

    assert_equal(buf_ring._tail, 128)
    ring.unsafe_delete_buf_ring(buf_ring^)
