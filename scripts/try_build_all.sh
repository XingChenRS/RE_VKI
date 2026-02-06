#!/bin/bash
# 两路尝试：1) 清华镜像 repo 拉取 + 构建  2) 独立构建（无 Android clang 时用系统 clang）
# 用法: 在 WSL 内核源码根目录上一级或内核源码根目录执行:
#   cd /path/to/android_16.0_kernel_MT6989 && ./scripts/try_build_all.sh
# 或: bash scripts/try_build_all.sh
set -e

KERNEL_SRC="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${LOG_FILE:-$KERNEL_SRC/AOSP_KERNEL_BUILD_LOG.txt}"
# 清华镜像根（TUNA 文档：设为此后 git config url 替换，repo 用标准 URL 即可）
# 见 https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/
TUNA="${KERNEL_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/git/AOSP}"

exec 3>&1
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=============== $(date -Iseconds) try_build_all ==============="
echo "KERNEL_SRC=$KERNEL_SRC"
echo "LOG_FILE=$LOG_FILE"
echo "KERNEL_MIRROR (mirror root)=$TUNA"

BUILT_IMAGE=""
export KERNEL_WS="${KERNEL_WS:-$HOME/kernel_aosp_ws}"

# ---------- 路径 1: 镜像 repo + 构建 ----------
echo "--- Path 1: repo with mirror root $TUNA ---"
export KERNEL_MIRROR="$TUNA"
if bash "$KERNEL_SRC/scripts/aosp_kernel_sync_and_build.sh"; then
  if [ -f "$KERNEL_WS/out/arch/arm64/boot/Image" ] || [ -f "$KERNEL_WS/out/arch/arm64/boot/Image.lz4" ]; then
    BUILT_IMAGE="$KERNEL_WS/out/arch/arm64/boot"
  fi
  if [ -f "$KERNEL_SRC/out/arch/arm64/boot/Image.lz4" ]; then
    BUILT_IMAGE="$KERNEL_SRC/out/arch/arm64/boot"
  fi
fi

# ---------- 路径 2: 独立构建（系统 clang 兜底）----------
if [ -z "$BUILT_IMAGE" ]; then
  echo "--- Path 2: standalone build (with USE_SYSTEM_CLANG=1 fallback) ---"
  export USE_SYSTEM_CLANG=1
  if (cd "$KERNEL_SRC" && ./build_wsl_standalone.sh); then
    if [ -f "$KERNEL_SRC/out/arch/arm64/boot/Image" ] || [ -f "$KERNEL_SRC/out/arch/arm64/boot/Image.lz4" ]; then
      BUILT_IMAGE="$KERNEL_SRC/out/arch/arm64/boot"
    fi
  fi
fi

echo "=============== $(date -Iseconds) try_build_all end ==============="
if [ -n "$BUILT_IMAGE" ]; then
  echo "SUCCESS: Kernel images in $BUILT_IMAGE"
  ls -la "$BUILT_IMAGE"/Image* 2>/dev/null || true
else
  echo "No kernel image produced. Check log: $LOG_FILE"
fi
