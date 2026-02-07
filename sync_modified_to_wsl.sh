#!/bin/bash
# 在 WSL 中执行：把 Windows 下的已修改文件同步到 WSL 构建目录
# 用法: bash sync_modified_to_wsl.sh
# 或: bash /mnt/c/Users/.../android_16.0_kernel_MT6989/sync_modified_to_wsl.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WSL_DEST="${WSL_BUILD_DEST:-/home/xingc/kernel_build_20260207_165431/android_16.0_kernel_MT6989}"

echo "源: $SCRIPT_DIR"
echo "目标: $WSL_DEST"
mkdir -p "$WSL_DEST/include/uapi/linux/netfilter"
mkdir -p "$WSL_DEST/include/uapi/linux/netfilter_ipv6"
mkdir -p "$WSL_DEST/include/uapi/linux/netfilter_ipv4"
mkdir -p "$WSL_DEST/kernel"

cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter/xt_dscp.h"    "$WSL_DEST/include/uapi/linux/netfilter/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter/xt_mark.h"    "$WSL_DEST/include/uapi/linux/netfilter/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter/xt_rateest.h" "$WSL_DEST/include/uapi/linux/netfilter/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter/xt_connmark.h" "$WSL_DEST/include/uapi/linux/netfilter/"
cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter/xt_TCPMSS.h"  "$WSL_DEST/include/uapi/linux/netfilter/"
cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter_ipv6/ip6t_hl.h" "$WSL_DEST/include/uapi/linux/netfilter_ipv6/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/include/uapi/linux/netfilter_ipv4/ipt_ttl.h" "$WSL_DEST/include/uapi/linux/netfilter_ipv4/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/kernel/Makefile"   "$WSL_DEST/kernel/"
cp -f "$SCRIPT_DIR/net/netfilter/Makefile" "$WSL_DEST/net/netfilter/"
cp -f "$SCRIPT_DIR/Kconfig"           "$WSL_DEST/"
cp -f "$SCRIPT_DIR/build_with_device_extract.sh" "$WSL_DEST/"
cp -f "$SCRIPT_DIR/README.md" "$WSL_DEST/" 2>/dev/null || true
mkdir -p "$WSL_DEST/docs"
cp -f "$SCRIPT_DIR/docs/BUILD_REPRODUCE.md" "$WSL_DEST/docs/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/docs/BUILD_FIXES_LOG.md" "$WSL_DEST/docs/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/docs/CHANGELOG.md" "$WSL_DEST/docs/" 2>/dev/null || true
chmod +x "$WSL_DEST/build_with_device_extract.sh"

echo "已同步。可在 WSL 中执行: cd $WSL_DEST && ./build_with_device_extract.sh"
