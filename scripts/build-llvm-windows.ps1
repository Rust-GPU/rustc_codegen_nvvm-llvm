$ErrorActionPreference = 'Stop'

# Build LLVM from source on Windows. Produces an install tree at
# $env:INSTALL_PREFIX matching the layout scripts/package-prebuilt.sh expects.
#
# Required env:
#   LLVM_VERSION    e.g. 7.1.0 or 19.1.7
#   INSTALL_PREFIX  absolute path; cmake --install target
#
# Notes on toolchain choice:
#   - LLVM 19+ builds cleanly with MSVC v143 (default on windows-2022).
#   - LLVM 7 predates a number of MSVC C++ conformance fixes and will not
#     compile under MSVC v143 without source patches. We sidestep that by
#     using clang-cl from the LLVM toolchain preinstalled on windows-2022,
#     which is more permissive while still producing MSVC-ABI binaries.
#   - LLVM_BUILD_LLVM_DYLIB is unsupported on Windows; consumers link against
#     the static archives that build.rs already prefers by default.

if (-not $env:LLVM_VERSION)   { throw 'LLVM_VERSION must be set' }
if (-not $env:INSTALL_PREFIX) { throw 'INSTALL_PREFIX must be set' }

$llvmVersion = $env:LLVM_VERSION
$installPrefix = $env:INSTALL_PREFIX
$llvmMajor = [int]($llvmVersion -split '\.')[0]

$workDir = if ($env:WORK_DIR) { $env:WORK_DIR } else { Join-Path $PWD 'llvm-src' }
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
Set-Location $workDir

# Use Git for Windows' GNU tar by full path. The default `tar` on PATH is
# C:\Windows\System32\tar.exe (bsdtar) which hangs on .tar.xz — see
# actions/runner-images#282. Prepending Git's bin dir to PATH also lets
# GNU tar find `xz` when shelling out for the -J path.
$gitBin = 'C:\Program Files\Git\usr\bin'
$gitTar = Join-Path $gitBin 'tar.exe'
if (-not (Test-Path $gitTar)) { throw "Git for Windows tar.exe not found at $gitTar" }
$env:PATH = "$gitBin;$env:PATH"

function Get-LlvmTarball {
    param([string]$name)
    if (Test-Path $name) { return }
    $url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-$llvmVersion/$name"
    Write-Host "Downloading $url"
    curl.exe -fL -o $name $url
    if ($LASTEXITCODE -ne 0) { throw "download failed: $name" }
}

function Expand-LlvmTarball {
    param([string]$name, [string[]]$paths)
    if ($paths) { & $gitTar -xf $name @paths } else { & $gitTar -xf $name }
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed: $name" }
}

if ($llvmMajor -le 7) {
    $tarball  = "llvm-$llvmVersion.src.tar.xz"
    $srcDir   = "llvm-$llvmVersion.src"
    $cmakeSrc = '..'
} else {
    $tarball  = "llvm-project-$llvmVersion.src.tar.xz"
    $srcDir   = "llvm-project-$llvmVersion.src"
    $cmakeSrc = '../llvm'
}

if (-not (Test-Path $srcDir)) {
    Get-LlvmTarball $tarball
    if ($llvmMajor -le 7) {
        Expand-LlvmTarball $tarball
    } else {
        # clang/test/Driver/Inputs has out-of-order symlinks that msys-tar
        # cannot create on Windows (CreateSymbolicLink requires the target's
        # FILE/DIR type, which it determines by stat'ing — fails when the
        # target hasn't been extracted yet). The build only needs llvm/,
        # cmake/, and third-party/, so extract just those three subtrees.
        Expand-LlvmTarball $tarball @("$srcDir/llvm", "$srcDir/cmake", "$srcDir/third-party")
    }

    # LLVM 7 ships with uninitialized members in ManagedStaticBase, which
    # under modern MSVC turns the AllSubCommands ManagedStatic into a
    # dynamic-init that wipes the cl::opt list — making -gen-attrs and most
    # of llvm-tblgen's options invisible at runtime. Backport the upstream
    # fix (LLVM #40712 / D80433). See the patch header for full details.
    if ($llvmMajor -le 7) {
        $patch = Join-Path $gitBin 'patch.exe'
        if (-not (Test-Path $patch)) { throw "patch.exe not found at $patch" }
        $patchFile = Join-Path $PSScriptRoot 'patches\llvm7-managedstatic-msvc.patch'
        Push-Location $srcDir
        try {
            & $patch -p1 --binary -i $patchFile
            if ($LASTEXITCODE -ne 0) { throw "patch failed: $patchFile" }
        } finally {
            Pop-Location
        }
    }
}

Set-Location $srcDir
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

Write-Host "Configuring cmake"

$cmakeArgs = @(
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DLLVM_TARGETS_TO_BUILD=X86;NVPTX',
    '-DLLVM_ENABLE_ASSERTIONS=OFF',
    '-DLLVM_ENABLE_BINDINGS=OFF',
    '-DLLVM_INCLUDE_EXAMPLES=OFF',
    '-DLLVM_INCLUDE_TESTS=OFF',
    '-DLLVM_INCLUDE_BENCHMARKS=OFF',
    '-DLLVM_ENABLE_ZLIB=OFF',
    '-DLLVM_ENABLE_TERMINFO=OFF',
    "-DCMAKE_INSTALL_PREFIX=$installPrefix"
)

if ($llvmMajor -le 7) {
    $clangCl = 'C:/Program Files/LLVM/bin/clang-cl.exe'
    if (-not (Test-Path $clangCl)) {
        throw "clang-cl required for LLVM 7 builds was not found at $clangCl"
    }
    $cmakeArgs += @(
        "-DCMAKE_C_COMPILER=$clangCl",
        "-DCMAKE_CXX_COMPILER=$clangCl"
    )
}

$cmakeArgs += $cmakeSrc

cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) { throw 'cmake configure failed' }

Write-Host "Building (ninja -j $env:NUMBER_OF_PROCESSORS)"
ninja -j $env:NUMBER_OF_PROCESSORS
if ($LASTEXITCODE -ne 0) { throw 'ninja build failed' }

Write-Host "Installing to $installPrefix"
ninja install
if ($LASTEXITCODE -ne 0) { throw 'ninja install failed' }

Write-Host "Done."
