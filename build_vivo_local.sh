#!/bin/bash
# 本地编译 vivo GKI 内核（WSL/Ubuntu）
# 参考: https://blog.liaoke.xyz/p/android-gki-kernel-compile/
#
# 首次在 WSL 请先安装依赖（一次性）:
#   sudo apt-get update
#   sudo apt-get install -y build-essential clang lld llvm libncurses-dev flex bison libssl-dev bc libelf-dev gcc-aarch64-linux-gnu
# 然后在本目录执行: ./build_vivo_local.sh
#
# 使用本地 AOSP Clang（例如 aospclang/linux-x86 拉取到仓库旁）:
#   export CLANG_PATH="/mnt/c/Users/XingChenRS/Documents/android_16.0_kernel_MT6989.tar/aospclang/linux-x86/clang-r547379/bin"
#   ./build_vivo_local.sh
set -e

KERNEL_ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$KERNEL_ROOT/out"
cd "$KERNEL_ROOT"

if [ ! -f arch/arm64/configs/gki_defconfig ]; then
  echo "Error: run this script from kernel source root (arch/arm64/configs/gki_defconfig not found)"
  exit 1
fi

# 可选：使用 AOSP Clang。若未设置则用系统 clang
if [ -n "$CLANG_PATH" ] && [ -x "$CLANG_PATH/clang" ]; then
  export PATH="$CLANG_PATH:$PATH"
  echo "Using Clang from: $CLANG_PATH"
else
  if ! command -v clang &>/dev/null; then
    echo "Install clang and cross compiler (WSL/Ubuntu):"
    echo "  sudo apt-get update && sudo apt-get install -y build-essential clang lld llvm libncurses-dev flex bison libssl-dev bc libelf-dev libelf1 gcc-aarch64-linux-gnu"
    exit 1
  fi
  if ! command -v llvm-ar &>/dev/null; then
    echo "Install llvm-ar (required when LLVM=1): sudo apt-get install -y llvm"
    exit 1
  fi
  echo "Using system Clang: $(which clang)"
fi

# 参考博客：GKI 5.10+ 使用纯 clang/llvm
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export HOSTCC=clang
export LD=ld.lld
export LLVM=1
export LLVM_IAS=1
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
# LLVM=1 时内核会调用 llvm-ar，确保在 PATH 中
export AR=llvm-ar

# 内存紧张时可加: export LTO=thin
# export LTO=thin

mkdir -p "$OUT_DIR"

# 合并 gki_defconfig + vivo_restore_gki.fragment
if [ -f scripts/kconfig/merge_config.sh ]; then
  echo "Merging gki_defconfig + vivo_restore_gki.fragment..."
  KCONFIG_CONFIG="$OUT_DIR/.config" scripts/kconfig/merge_config.sh -m -r \
    arch/arm64/configs/gki_defconfig \
    arch/arm64/configs/vivo_restore_gki.fragment
else
  echo "merge_config.sh not found, using cat + olddefconfig"
  cat arch/arm64/configs/gki_defconfig arch/arm64/configs/vivo_restore_gki.fragment > "$OUT_DIR/.config"
fi

make O="$OUT_DIR" ARCH=arm64 olddefconfig
echo "Building Image, Image.gz, Image.lz4, modules..."
make O="$OUT_DIR" ARCH=arm64 -j"$(nproc)" Image Image.gz Image.lz4 modules

echo ""
echo "Build done. Kernel images:"
echo "  $OUT_DIR/arch/arm64/boot/Image"
echo "  $OUT_DIR/arch/arm64/boot/Image.gz"
echo "  $OUT_DIR/arch/arm64/boot/Image.lz4"
echo "Pack with AnyKernel3 or replace in boot.img (e.g. magiskboot)."
