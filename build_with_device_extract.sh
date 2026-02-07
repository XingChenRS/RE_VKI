#!/bin/bash
# 使用实机提取的 config 与 DTB 构建内核，并用 AOSP Clang 编译
# 重要：config 中与缺失源码（vivo_rsc 等）相关的选项会被剔除，其余与实机一致；
#       DTB 直接使用实机提取的二进制，打包 boot 时请用 out/device_dtb/ 内的 fdt.dtb。
# 数据不一致可能导致不开机或数据丢失，请务必在实机测试前备份。
set -e

KERNEL_ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$KERNEL_ROOT/out"
# 实机提取目录：优先 device_extract/vivo_x100pro，否则 device_extract/extracted_*
EXTRACT_BASE="$KERNEL_ROOT/device_extract"
EXTRACT_DIR=""
for d in "$EXTRACT_BASE/vivo_x100pro" "$EXTRACT_BASE"/extracted_*; do
  [ -d "$d" ] && [ -f "$d/02_kernel_config/running_kernel.config" ] && [ -f "$d/04_device_tree/fdt.dtb" ] && EXTRACT_DIR="$d" && break
done
if [ -z "$EXTRACT_DIR" ]; then
  echo "Error: 未找到实机提取目录。请在 device_extract/vivo_x100pro/ 或 device_extract/extracted_*/ 下同时存在："
  echo "  02_kernel_config/running_kernel.config"
  echo "  04_device_tree/fdt.dtb"
  exit 1
fi
echo "使用实机提取目录: $EXTRACT_DIR"

# 仅使用 AOSP Clang，不使用系统 Clang
if [ -n "$CLANG_PATH" ] && [ -x "$CLANG_PATH/clang" ]; then
  AOSP_CLANG_BIN="$CLANG_PATH"
else
  PARENT="$(dirname "$KERNEL_ROOT")"
  for rel in "aospclang/linux-x86/clang-r547379/bin" "aospclang/linux-x86/clang-r536225/bin" "aospclang/linux-x86/clang-r522817/bin"; do
    [ -x "$PARENT/$rel/clang" ] && AOSP_CLANG_BIN="$PARENT/$rel" && break
  done
fi

if [ -z "$AOSP_CLANG_BIN" ] || [ ! -x "$AOSP_CLANG_BIN/clang" ]; then
  echo "Error: 未找到 AOSP Clang。请将 aospclang/linux-x86/clang-r547379/bin 置于内核源码上级目录，或设置 CLANG_PATH=该bin目录。"
  exit 1
fi

if ! "$AOSP_CLANG_BIN/clang" --version >/dev/null 2>&1; then
  echo "Error: AOSP Clang 无法执行（请确认 clang.real 为 ELF 或指向 clang-xx 的符号链接，且位于 WSL 原生目录）。"
  echo "  uname -m: $(uname -m)"
  echo "  file clang: $(file "$AOSP_CLANG_BIN/clang" 2>/dev/null || true)"
  [ -e "$AOSP_CLANG_BIN/clang.real" ] && echo "  file clang.real: $(file "$AOSP_CLANG_BIN/clang.real" 2>/dev/null || true)"
  exit 1
fi

export PATH="$AOSP_CLANG_BIN:$PATH"
export CC="$AOSP_CLANG_BIN/clang"
export HOSTCC="$AOSP_CLANG_BIN/clang"
export LD="$AOSP_CLANG_BIN/ld.lld"
export AR="$AOSP_CLANG_BIN/llvm-ar"
echo "使用 AOSP Clang: $AOSP_CLANG_BIN"

# 实机 config → out/.config，并剔除源码中不存在的选项（vivo_rsc 等）
DEVICE_CONFIG="$EXTRACT_DIR/02_kernel_config/running_kernel.config"
if [ ! -f "$DEVICE_CONFIG" ]; then
  echo "Error: 实机 config 不存在: $DEVICE_CONFIG"
  exit 1
fi
mkdir -p "$OUT_DIR"
echo "从实机 config 生成 .config，并剔除 CONFIG_VIVO_* / CONFIG_RSC_* / CONFIG_VIVONET*（源码中无对应 Kconfig）..."
grep -v -E '^CONFIG_VIVO_|^CONFIG_RSC_|^CONFIG_VIVONET' "$DEVICE_CONFIG" > "$OUT_DIR/.config"
# 实机可能使用 mtk_signing_key.pem 等本机不存在的密钥，改为默认以便内核自动生成
sed -i 's|^CONFIG_MODULE_SIG_KEY=.*|CONFIG_MODULE_SIG_KEY="certs/signing_key.pem"|' "$OUT_DIR/.config"
# 本地构建若无 pahole，BTF 生成会失败；关闭 BTF 以便编译通过（可选：安装 dwarves 后注释掉以启用 BTF）
sed -i 's/^CONFIG_DEBUG_INFO_BTF=.*/CONFIG_DEBUG_INFO_BTF=n/' "$OUT_DIR/.config"
sed -i 's/^CONFIG_DEBUG_INFO_BTF_MODULES=.*/CONFIG_DEBUG_INFO_BTF_MODULES=n/' "$OUT_DIR/.config"
grep -q '^CONFIG_DEBUG_INFO_BTF=' "$OUT_DIR/.config" || echo 'CONFIG_DEBUG_INFO_BTF=n' >> "$OUT_DIR/.config"
grep -q '^CONFIG_DEBUG_INFO_BTF_MODULES=' "$OUT_DIR/.config" || echo 'CONFIG_DEBUG_INFO_BTF_MODULES=n' >> "$OUT_DIR/.config"

# 校验：设备内核版本与源码大版本一致（均为 6.1.x）
DEVICE_VER=$(grep -m1 '^# Linux/arm64' "$DEVICE_CONFIG" 2>/dev/null | sed 's/.* \([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/') || true
V=$(grep '^VERSION =' "$KERNEL_ROOT/Makefile" | awk '{print $3}'); P=$(grep '^PATCHLEVEL =' "$KERNEL_ROOT/Makefile" | awk '{print $3}'); S=$(grep '^SUBLEVEL =' "$KERNEL_ROOT/Makefile" | awk '{print $3}')
SRC_VER="${V}.${P}.${S}"
if [ -n "$DEVICE_VER" ] && [ -n "$SRC_VER" ]; then
  DEVICE_MAJOR=$(echo "$DEVICE_VER" | cut -d. -f1,2)
  SRC_MAJOR=$(echo "$SRC_VER" | cut -d. -f1,2)
  if [ "$DEVICE_MAJOR" != "$SRC_MAJOR" ]; then
    echo "Warning: 实机内核版本 $DEVICE_VER 与源码版本 $SRC_VER 大版本不一致，可能影响开机或兼容性。"
  else
    echo "实机内核版本: $DEVICE_VER  源码版本: $SRC_VER"
  fi
fi

cd "$KERNEL_ROOT"
export ARCH=arm64
export SUBARCH=arm64
# CC/HOSTCC/LD/AR 已在上面设为 AOSP 完整路径
export LLVM=1
export LLVM_IAS=1
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-

make O="$OUT_DIR" ARCH=arm64 olddefconfig
# Image.lz4 需要系统安装 lz4 命令（apt install lz4）；若无则只编 Image/Image.gz/modules
if command -v lz4 >/dev/null 2>&1; then
  echo "开始编译 Image, Image.gz, Image.lz4, modules..."
  make O="$OUT_DIR" ARCH=arm64 -j"$(nproc)" Image Image.gz Image.lz4 modules
else
  echo "开始编译 Image, Image.gz, modules（未检测到 lz4，跳过 Image.lz4；需时可 apt install lz4）..."
  make O="$OUT_DIR" ARCH=arm64 -j"$(nproc)" Image Image.gz modules
fi

# 复制实机 DTB 到输出目录，供后续打包 boot 使用（切勿用其它 DTB 替换，否则可能不开机）
DTB_OUT="$OUT_DIR/device_dtb"
mkdir -p "$DTB_OUT"
cp "$EXTRACT_DIR/04_device_tree/fdt.dtb" "$DTB_OUT/fdt.dtb"
echo "已复制实机 DTB 到: $DTB_OUT/fdt.dtb（打包 boot 时请使用此文件）"

echo ""
echo "========== 构建完成 =========="
echo "内核镜像: $OUT_DIR/arch/arm64/boot/Image、Image.gz（若已安装 lz4 则还有 Image.lz4）"
echo "实机 DTB: $DTB_OUT/fdt.dtb（必须与上述 Image 一起用于打包 boot，否则可能不开机或异常）"
echo "打包 boot 时请仅替换内核二进制，保留原 boot 的 ramdisk 与命令行，并使用本目录下的 fdt.dtb。"
