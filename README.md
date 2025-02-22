# io_uring

This is a Linux [`io_uring`](https://unixism.net/loti/) userspace
interface for Mojo.

This repo includes source code for:

- linux_raw (Linux userspace API)
- mojix (I/O wrappers)
- io_uring


## Environment
For Mojo LSP to work correctly in editors like [`Helix`](https://github.com/helix-editor/helix)
some environment variables need to be set/modified. You can use [`direnv`](https://direnv.net/)
or look at the `.envrc` file for values.

## Build
```
./scripts/build.sh
```

## Tests
```
./scripts/run_tests.sh
```

## Requirements
Currently only x86_64 platform is supported. Mojo nightly builds are required.


## License

This repository is licensed under the Apache License v2.0 with LLVM Exceptions
(see the LLVM [License](https://llvm.org/LICENSE.txt)).
