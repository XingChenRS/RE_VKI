#!/bin/bash
# WSL 下 vivo GKI 内核构建入口
# 用法: 在 WSL 中于内核源码根目录执行: ./build_wsl.sh
# 或: ./build_wsl.sh /path/to/kernel/source
# 依赖: 需先准备好 kernel/build 与 prebuilts（见下方 PREBUILTS 说明）

set -e
cd "$(dirname "$0")"
KERNEL_SRC="$(pwd)"
WS_DIR="${KERNEL_WS_DIR:-$KERNEL_SRC/../kernel_build_ws}"
BUILD_REPO_URL="${KERNEL_BUILD_REPO:-https://android.googlesource.com/kernel/build}"
BRANCH="${KERNEL_BUILD_BRANCH:-main}"

echo "[build_wsl] Kernel source: $KERNEL_SRC"
echo "[build_wsl] Workspace dir:  $WS_DIR"
mkdir -p "$WS_DIR"
cd "$WS_DIR"

# 1. 克隆或更新 kernel/build
if [ ! -d "build" ]; then
  echo "[build_wsl] Cloning kernel/build..."
  git clone --depth 1 "$BUILD_REPO_URL" -b "$BRANCH" build
else
  echo "[build_wsl] Using existing build/"
fi

# 2. 提供 common -> 内核源码（供 BUILD_CONFIG=common/build.config... 使用）
if [ -L "common" ]; then
  rm -f common
fi
if [ ! -d "common" ]; then
  ln -sf "$KERNEL_SRC" common
  echo "[build_wsl] Linked common -> $KERNEL_SRC"
fi

# 3. 检查 prebuilts（clang）
CLANG_VERSION="r487747c"
CLANG_DIR="prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}"
if [ ! -d "$CLANG_DIR/bin" ]; then
  echo "[build_wsl] Prebuilts not found at $CLANG_DIR"
  echo "[build_wsl] You need to provide Android clang. Options:"
  echo "  A) From AOSP: repo sync 后 prebuilts 在 platform/prebuilts/clang/host/linux-x86/"
  echo "     复制或链接: cp -r /path/to/aosp/prebuilts ."
  echo "  B) 仅下载 clang: 从 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/"
  echo "     仅拉取 clang-${CLANG_VERSION} 目录到 $WS_DIR/$CLANG_DIR"
  echo "  C) 使用 build 自带的 fetch: 进入 build/ 执行 ./fetch_prebuilts.sh 或类似（若存在）"
  if [ -f "build/fetch_prebuilts.sh" ]; then
    echo "[build_wsl] Running build/fetch_prebuilts.sh..."
    build/fetch_prebuilts.sh || true
  fi
  if [ ! -d "$CLANG_DIR/bin" ]; then
    echo "[build_wsl] Aborting: prebuilts still missing."
    exit 1
  fi
fi

# 4. 设置 ROOT_DIR 并执行 build.sh
export ROOT_DIR="$WS_DIR"
export BUILD_CONFIG=common/build.config.gki.aarch64.vivo_restore
# 可选：指定输出目录，避免写回 kernel 树
export OUT_DIR="${OUT_DIR:-$WS_DIR/out/android14-6.1}"
echo "[build_wsl] ROOT_DIR=$ROOT_DIR BUILD_CONFIG=$BUILD_CONFIG OUT_DIR=$OUT_DIR"
echo "[build_wsl] Starting build..."
build/build.sh "$@"
