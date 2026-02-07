#!/bin/bash
# 在 WSL 内执行：将编译所需内容拷到 WSL 原生目录后构建，避免 /mnt/c 下执行 ELF 异常。
# 用法：在 WSL 中运行
#   bash /mnt/c/.../android_16.0_kernel_MT6989/copy_to_wsl_and_build.sh
# 或先 cd 到脚本所在目录再 ./copy_to_wsl_and_build.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 若当前在 /mnt/c/...，则认定在 Windows 盘符上
WSL_DEST="${WSL_BUILD_ROOT:-$HOME}/kernel_build_$(date +%Y%m%d_%H%M%S)"
KERNEL_NAME="android_16.0_kernel_MT6989"
PARENT="$(dirname "$SCRIPT_DIR")"

echo "源目录: $SCRIPT_DIR"
echo "目标目录 (WSL 原生): $WSL_DEST"
mkdir -p "$WSL_DEST"

# 拷贝内核源码（含 device_extract、脚本）
echo "拷贝内核源码..."
cp -a "$SCRIPT_DIR" "$WSL_DEST/$KERNEL_NAME"

# 拷贝 AOSP Clang（若存在），便于在 WSL 原生路径下用
if [ -d "$PARENT/aospclang" ]; then
  echo "拷贝 aospclang..."
  cp -a "$PARENT/aospclang" "$WSL_DEST/"
fi

cd "$WSL_DEST/$KERNEL_NAME"
echo "已在 WSL 原生目录: $(pwd)"
echo "开始构建..."
./build_with_device_extract.sh

echo ""
echo "构建完成。产物在: $WSL_DEST/$KERNEL_NAME/out/"
