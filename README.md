# Prebuilt LLVM Libraries

This repo contains prebuilt LLVM 7.1.0 Libraries for Windows and Linux. 

These libraries are required by rustc_codegen_nvvm, however, LLVM is difficult to 
build, especially older versions of LLVM. Therefore, we ship prebuilt compressed 
7zip files which contain:
- `include/llvm` and `include/llvm-c`, these are required for building the LLVM shim.
- `lib/*`, these are the actual `.lib` files we tell rustc to include when building the codegen.

We do not include binaries other than llvm-config because they aren't needed for us.

The prebuilt libraries are pulled from the following locations:
- linux-aarch64: LLVM prebuilt downloads 7.1.0, AArch64 Linux
- linux-x86_64: LLVM prebuilt downloads 7.1.0, Ubuntu 14.04
- linux-x86: LLVM prebuilt downloads 7.1.0, FreeBSD11 i386
- windows-x86_64: https://github.com/vovkos/llvm-package-windows llvm-7.1.0-windows-amd64-msvc15-msvcrt
- windows-x86: https://github.com/vovkos/llvm-package-windows llvm-7.1.0-windows-x86-msvc15-msvcrt

We do not ship mac binaries because currently we only support CUDA 11 and up, and CUDA dropped MacOS support.
