#!/bin/bash
# WSL 独立构建脚本：不依赖 kernel/build 仓库，仅需预置 clang 或通过可选步骤下载。
# 用法: 在内核源码根目录执行: ./build_wsl_standalone.sh
# 依赖: make, gcc (host), libncurses-dev, flex, bison, libssl-dev, bc；以及 Android clang（见下方 PREBUILTS）
set -e

KERNEL_SRC="$(cd "$(dirname "$0")" && pwd)"
# 检查必要命令
for cmd in make; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[standalone] Missing: $cmd. In WSL run: sudo apt install build-essential libncurses-dev flex bison libssl-dev bc"
    exit 1
  fi
done
OUT_DIR="${OUT_DIR:-$KERNEL_SRC/out}"
CLANG_VERSION="${CLANG_VERSION:-r487747c}"
# 预编译 clang：可设 PREBUILTS_ROOT 或直接设 CLANG_BIN
# PREBUILTS_ROOT 可为 AOSP 的 prebuilts 根，或 clone 出的 linux-x86 仓库根（含 clang-r487747c/）
PREBUILTS_ROOT="${PREBUILTS_ROOT:-$KERNEL_SRC/../prebuilts}"
if [ -n "$CLANG_BIN" ]; then
  :
elif [ -x "$PREBUILTS_ROOT/clang-${CLANG_VERSION}/bin/clang" ]; then
  CLANG_BIN="$PREBUILTS_ROOT/clang-${CLANG_VERSION}/bin"
else
  CLANG_DIR="$PREBUILTS_ROOT/clang/host/linux-x86/clang-${CLANG_VERSION}"
  CLANG_BIN="$CLANG_DIR/bin"
fi

echo "[standalone] Kernel: $KERNEL_SRC"
echo "[standalone] Out:     $OUT_DIR"
echo "[standalone] Clang:   $CLANG_BIN"

# ----- 1. 准备 .config（合并 gki_defconfig + vivo_restore_gki.fragment）-----
mkdir -p "$OUT_DIR"
if [ ! -f "$OUT_DIR/.config" ]; then
  echo "[standalone] Generating merged defconfig..."
  TMP_CONFIG=$(mktemp)
  trap "rm -f $TMP_CONFIG" EXIT
  KCONFIG_CONFIG="$TMP_CONFIG" "$KERNEL_SRC/scripts/kconfig/merge_config.sh" -m -r \
    "$KERNEL_SRC/arch/arm64/configs/gki_defconfig" \
    "$KERNEL_SRC/arch/arm64/configs/vivo_restore_gki.fragment"
  cp "$TMP_CONFIG" "$OUT_DIR/.config"
  rm -f "$TMP_CONFIG"
  trap - EXIT
  echo "[standalone] Resolving defaults (olddefconfig)..."
  make -C "$KERNEL_SRC" O="$OUT_DIR" ARCH=arm64 olddefconfig
fi

# ----- 2. 检查 clang（可选 USE_SYSTEM_CLANG=1 用系统 clang 兜底）-----
USE_SYSTEM_CLANG="${USE_SYSTEM_CLANG:-0}"
if [ ! -x "$CLANG_BIN/clang" ]; then
  if [ "$USE_SYSTEM_CLANG" = "1" ] && command -v clang &>/dev/null; then
    echo "[standalone] Android clang not found; using system clang (USE_SYSTEM_CLANG=1). ABI may differ from GKI."
    CLANG_BIN="$(dirname "$(command -v clang)")"
  else
    echo "[standalone] Clang not found at $CLANG_BIN"
    echo "[standalone] Please provide Android clang ${CLANG_VERSION}. Options:"
    echo "  - From AOSP: copy prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION} to $CLANG_DIR"
    echo "  - Or set: PREBUILTS_ROOT=/path/to/parent (containing clang/host/linux-x86/clang-${CLANG_VERSION})"
    echo "  - Or: USE_SYSTEM_CLANG=1 to try system clang (ABI may differ)"
    exit 1
  fi
fi

export PATH="$CLANG_BIN:$PATH"
# 使用 Android NDK triple（与 build.config.constants 一致）
export CROSS_COMPILE=aarch64-linux-gnu-
# 若系统无 aarch64-linux-gnu-gcc，可用 clang 做交叉编译（内核支持）
if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
  echo "[standalone] aarch64-linux-gnu-gcc not found; using clang for cross-compile (CC=clang CLANG_TRIPLE=...)."
  export CC=clang
  export CLANG_TRIPLE=aarch64-linux-gnu-
fi

# ----- 3. 构建 -----
echo "[standalone] Building kernel (Image, Image.gz, Image.lz4, modules)..."
make -C "$KERNEL_SRC" O="$OUT_DIR" LLVM=1 LLVM_IAS=1 \
  ARCH=arm64 \
  CROSS_COMPILE="${CROSS_COMPILE}" \
  Image Image.gz Image.lz4 modules \
  -j"${MAKE_JOBS:-$(nproc)}" \
  "$@"

echo "[standalone] Done. Images: $OUT_DIR/arch/arm64/boot/Image*"
