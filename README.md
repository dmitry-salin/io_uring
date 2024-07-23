# io_uring

This is a Linux [`io_uring`](https://unixism.net/loti/) userspace
interface for Mojo.

This repo includes source code for:

- linux_raw (Linux userspace API)
- mojix (I/O wrappers)
- io_uring


## Tests
```
mojo test -I .
```

Some tests do not work with the test framework and require a separate file:
```
mojo -D MOJO_ENABLE_ASSERTIONS -I . run_tests.mojo
```

## Requirements
Currently only x86_64 platform is supported. Mojo nightly builds are required.


## License

This repository is licensed under the Apache License v2.0 with LLVM Exceptions
(see the LLVM [License](https://llvm.org/LICENSE.txt)).
