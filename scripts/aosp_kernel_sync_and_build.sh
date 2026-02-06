#!/bin/bash
# 在 WSL 中拉取 AOSP kernel 相关源码并尝试用本机内核树构建。
# 用法: 在 WSL 中执行: ./scripts/aosp_kernel_sync_and_build.sh
# 镜像: 按 https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/ 建议，设 KERNEL_MIRROR 为镜像根（见下）
set -e

KERNEL_SRC="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${LOG_FILE:-$KERNEL_SRC/AOSP_KERNEL_BUILD_LOG.txt}"
# 工作区：默认 WSL 家目录下，避免 /mnt 路径过长
KERNEL_WS="${KERNEL_WS:-$HOME/kernel_aosp_ws}"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== $(date -Iseconds) AOSP kernel sync & build ==="
echo "KERNEL_SRC=$KERNEL_SRC"
echo "KERNEL_WS=$KERNEL_WS"
echo "LOG_FILE=$LOG_FILE"

mkdir -p "$KERNEL_WS"
cd "$KERNEL_WS"

# 镜像：TUNA 文档建议用 git config url 替换，这样 repo 仍用标准 URL，所有拉取走镜像。
# 设 KERNEL_MIRROR 为镜像根，例如: export KERNEL_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/git/AOSP
# 不设则直连 https://android.googlesource.com
REPO_BASE="https://android.googlesource.com"
if [ -n "$KERNEL_MIRROR" ]; then
  echo "--- using mirror: git config url.${KERNEL_MIRROR}/.insteadof https://android.googlesource.com ---"
  git config --global url."${KERNEL_MIRROR}/".insteadOf "https://android.googlesource.com/"
  REPO_BASE="$KERNEL_MIRROR"
fi
REPO_URL="${REPO_BASE}/kernel/manifest"

# 1. repo init（尝试 android14-6.1，失败则尝试 main）
REPO_OK=false
if [ ! -d .repo ]; then
  echo "--- repo init $REPO_URL (branch android14-6.1 then main) ---"
  if repo init -u "$REPO_URL" -b android14-6.1 --depth=1 2>&1; then
    REPO_OK=true
  else
    echo "--- android14-6.1 failed, trying main ---"
    if repo init -u "$REPO_URL" -b main --depth=1 2>&1; then
      REPO_OK=true
    else
      echo "--- repo init failed. With mirror try: export KERNEL_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/git/AOSP ---"
    fi
  fi
else
  REPO_OK=true
  echo "--- .repo exists ---"
fi

# 2. repo sync（TUNA 建议并发不宜过高，-j4）
CLANG_VERSION="r487747c"
CLANG_PATH="prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}/bin/clang"

if [ "$REPO_OK" = true ]; then
  echo "--- repo sync -c -j4 (may take a long time, ~20-50GB) ---"
  repo sync -c -j4 || true
  if [ -d common ] && [ -d "$KERNEL_SRC/arch" ]; then
    echo "--- replacing common with local kernel tree ---"
    rm -rf common
    ln -sf "$KERNEL_SRC" common
  fi
fi

# 3. 若仍无 prebuilts clang，尝试仅克隆 clang 仓库
if [ ! -x "$CLANG_PATH" ]; then
  echo "--- prebuilts clang not at $CLANG_PATH ---"
  mkdir -p prebuilts/clang/host/linux-x86
  if [ ! -d prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION} ]; then
    echo "--- git clone prebuilts clang (single version) ---"
    (cd prebuilts/clang/host/linux-x86 && git clone --depth 1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 repo_tmp 2>/dev/null && mv repo_tmp/clang-${CLANG_VERSION} . 2>/dev/null; rm -rf repo_tmp) || true
  fi
  ls -la prebuilts/clang/host/linux-x86/ 2>/dev/null || true
fi

# 4. 构建：有 build/build.sh 则用，否则用 standalone + PREBUILTS_ROOT
export PREBUILTS_ROOT="$KERNEL_WS"
if [ -f build/build.sh ] && [ -x "$CLANG_PATH" ]; then
  echo "--- building with build/build.sh ---"
  export BUILD_CONFIG=common/build.config.gki.aarch64.vivo_restore
  build/build.sh -j"${MAKE_JOBS:-$(nproc)}" || true
else
  echo "--- using standalone build (PREBUILTS_ROOT=$KERNEL_WS) ---"
  if [ -x "$CLANG_PATH" ]; then
    export PREBUILTS_ROOT="$KERNEL_WS"
  fi
  "$KERNEL_SRC/build_wsl_standalone.sh" || true
fi

echo "=== $(date -Iseconds) end ==="
