# Prebuilt LLVM Libraries

This repository builds and publishes prebuilt LLVM libraries used by [`rustc_codegen_nvvm`](https://github.com/Rust-GPU/Rust-CUDA/tree/main/crates/rustc_codegen_nvvm). Building LLVM from source is slow and finicky — especially older versions — so we publish pinned, reproducible tarballs to GitHub releases that `rustc_codegen_nvvm`'s `build.rs` can download.

The repo itself contains only the build scripts and CI; the tarballs live as release assets so cloning stays fast.

## What's published

Each release is tagged `llvm-<version>` (e.g. `llvm-19.1.7`) and ships two assets:

| Asset                  | Target triple             |
|------------------------|---------------------------|
| `linux-x86_64.tar.xz`  | `x86_64-unknown-linux-gnu` |
| `windows-x86_64.tar.xz` | `x86_64-pc-windows-msvc`  |

Download URLs follow the standard GitHub releases pattern:

```
https://github.com/<owner>/<repo>/releases/download/llvm-<version>/<artifact>.tar.xz
```

CUDA dropped macOS support before any Rust-CUDA-relevant version, so no Darwin builds are produced.

Each tarball expands to a single top-level directory matching the target name (`linux-x86_64/` or `windows-x86_64/`) containing:

```
bin/
  llvm-config[.exe]   # probed by build.rs for components, cxxflags, libs
  llvm-as[.exe]       # used by the LLVM 19 build path to assemble libintrinsics.ll
include/
  llvm/
  llvm-c/
lib/
  *.{a,so,lib}        # static archives (and dylib on Linux)
```

`bin/cmake` and `lib/pkgconfig` are stripped because `build.rs` consumes the link-line via `llvm-config`, not `find_package(LLVM)`.

## Build configuration

Both LLVM 7 and LLVM 19 are built with the same flags:

- `CMAKE_BUILD_TYPE=Release`
- `LLVM_TARGETS_TO_BUILD=X86;NVPTX`
- `LLVM_ENABLE_ASSERTIONS=OFF`
- `LLVM_ENABLE_BINDINGS=OFF`
- `LLVM_INCLUDE_{EXAMPLES,TESTS,BENCHMARKS}=OFF`
- Linux only: `LLVM_BUILD_LLVM_DYLIB=ON`, `LLVM_LINK_LLVM_DYLIB=ON`, `LLVM_ENABLE_{ZLIB,TERMINFO}=ON`

Linux builds run on `ubuntu-22.04` (glibc 2.35), giving a floor that matches the rust-cuda container baseline. Windows builds run on `windows-2022`. **LLVM 7 on Windows is compiled with `clang-cl` from the preinstalled LLVM toolchain** because MSVC v143 (the default compiler on `windows-2022`) refuses LLVM 7's older sources without source patches; LLVM 19 uses MSVC directly.

## How to build and publish a new version

Trigger [`build-llvm.yml`](.github/workflows/build-llvm.yml) from the Actions tab via **Run workflow**, supplying the LLVM version (e.g. `7.1.0` or `19.1.7`). The matrix runs on Linux and Windows runners. With the default `release: true` input, the workflow then creates (or updates) a release tagged `llvm-<version>` and uploads both tarballs as assets — re-running clobbers the existing assets, so it's safe to retry. Untick `release` to build without publishing; tarballs are still available as run artifacts on the workflow run page.

## How to reproduce locally

The CI uses these scripts directly. To rebuild a tarball locally:

```sh
# Linux
LLVM_VERSION=19.1.7 INSTALL_PREFIX="$PWD/install" ./scripts/build-llvm-linux.sh
INSTALL_PREFIX="$PWD/install" ARTIFACT_NAME=linux-x86_64 ./scripts/package-prebuilt.sh

# Windows (PowerShell)
$env:LLVM_VERSION = '19.1.7'; $env:INSTALL_PREFIX = "$PWD\install"
./scripts/build-llvm-windows.ps1
$env:ARTIFACT_NAME = 'windows-x86_64'
bash ./scripts/package-prebuilt.sh
```
