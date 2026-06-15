Verilator build and run instructions
=================================

This directory contains a small Verilator C++ harness to run an automated host
scenario for `lpu_sot_top`.

Prerequisites (macOS):

- Install Verilator: `brew install verilator`
- Install a C++ compiler (clang/gcc) and make (Xcode command line tools)

Build and run:

```bash
# from repository root
cd open-lpu/verilator
bash build.sh
# then run
./build/verilator/Vlpu_sot_top
```

The harness performs the following sequence:
- reset chip
- program policy register to deny all clients
- request key as client 1 (expect no response)
- program policy bit to allow client 1
- request key as client 1 (expect a response)

Note: this is a functional test harness intended for early validation. For
integration into a larger CI flow, consider adding a Verilator + CMake or
Makefile wrapper and/or a Python runner to parse test results.

