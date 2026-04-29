#!/usr/bin/env bash
set -euo pipefail

# Build LLVM from source on Linux. Produces an install tree at $INSTALL_PREFIX
# matching the layout that scripts/package-prebuilt.sh expects.
#
# Required env:
#   LLVM_VERSION    e.g. 7.1.0 or 19.1.7
#   INSTALL_PREFIX  absolute path; cmake --install target
#
# Optional env:
#   WORK_DIR        where to extract sources (default: $PWD/llvm-src)

: "${LLVM_VERSION:?LLVM_VERSION must be set (e.g. 7.1.0 or 19.1.7)}"
: "${INSTALL_PREFIX:?INSTALL_PREFIX must be set}"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  TARGETS="X86;NVPTX" ;;
  aarch64) TARGETS="AArch64;NVPTX" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

LLVM_MAJOR="${LLVM_VERSION%%.*}"

# LLVM 7.x ships `llvm-X.Y.Z.src.tar.xz` (just the llvm subtree, cmake root is
# the extracted dir itself). LLVM 8+ ships `llvm-project-X.Y.Z.src.tar.xz`
# (monorepo, cmake root is the `llvm/` subdir).
if [ "$LLVM_MAJOR" -le 7 ]; then
  TARBALL="llvm-${LLVM_VERSION}.src.tar.xz"
  SRC_DIR="llvm-${LLVM_VERSION}.src"
  CMAKE_SRC=".."
else
  TARBALL="llvm-project-${LLVM_VERSION}.src.tar.xz"
  SRC_DIR="llvm-project-${LLVM_VERSION}.src"
  CMAKE_SRC="../llvm"
fi

WORK_DIR="${WORK_DIR:-$PWD/llvm-src}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

if [ ! -d "$SRC_DIR" ]; then
  curl -sSfL -O "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${TARBALL}"
  tar -xf "$TARBALL"
fi

cd "$SRC_DIR"
mkdir -p build
cd build

cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="$TARGETS" \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_ENABLE_ZLIB=ON \
  -DLLVM_ENABLE_TERMINFO=ON \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  "$CMAKE_SRC"

ninja -j"$(nproc)"
ninja install
