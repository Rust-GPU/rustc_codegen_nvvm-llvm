#!/usr/bin/env bash
set -euo pipefail

# Repackage an LLVM install tree into the tarball layout that
# rustc_codegen_nvvm/build.rs expects:
#
#   <ARTIFACT_NAME>/
#     bin/llvm-config[.exe]
#     bin/llvm-as[.exe]      (only used by the LLVM 19 build path)
#     include/llvm/...
#     include/llvm-c/...
#     lib/*                  (static archives + shared libs on Linux)
#
# Required env:
#   INSTALL_PREFIX  the install tree produced by build-llvm-{linux,windows}
#   ARTIFACT_NAME   e.g. linux-x86_64 or windows-x86_64

: "${INSTALL_PREFIX:?INSTALL_PREFIX must be set}"
: "${ARTIFACT_NAME:?ARTIFACT_NAME must be set}"

case "$ARTIFACT_NAME" in
  windows-*) EXE_SUFFIX=".exe" ;;
  *)         EXE_SUFFIX="" ;;
esac

OUT_DIR="$PWD/$ARTIFACT_NAME"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/bin" "$OUT_DIR/include" "$OUT_DIR/lib"

cp "$INSTALL_PREFIX/bin/llvm-config$EXE_SUFFIX" "$OUT_DIR/bin/"
if [ -f "$INSTALL_PREFIX/bin/llvm-as$EXE_SUFFIX" ]; then
  cp "$INSTALL_PREFIX/bin/llvm-as$EXE_SUFFIX" "$OUT_DIR/bin/"
fi

cp -R "$INSTALL_PREFIX/include/llvm"   "$OUT_DIR/include/"
cp -R "$INSTALL_PREFIX/include/llvm-c" "$OUT_DIR/include/"

# Copy the entire lib tree, then drop subdirectories build.rs never reads.
# llvm-config provides the link-line directly, so we don't need cmake/ or
# pkgconfig/ — and pkgconfig contains absolute build-host paths anyway.
cp -R "$INSTALL_PREFIX/lib/." "$OUT_DIR/lib/"
rm -rf "$OUT_DIR/lib/cmake" "$OUT_DIR/lib/pkgconfig"

tar -cJf "$ARTIFACT_NAME.tar.xz" "$ARTIFACT_NAME"
ls -lh "$ARTIFACT_NAME.tar.xz"
