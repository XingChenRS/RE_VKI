# WSL 下构建 vivo GKI 内核

## 1. 安装构建依赖（在 WSL 中执行一次）

```bash
sudo apt update
sudo apt install -y build-essential libncurses-dev flex bison libssl-dev bc
```

如需交叉编译 arm64，可安装：

```bash
sudo apt install -y gcc-aarch64-linux-gnu
```

## 2. 准备 Android Clang 工具链

构建需使用与 GKI 一致的 clang 版本（当前为 **r487747c**），否则 KMI/ABI 可能不兼容。

**方式 A：从 AOSP 复制（推荐）**

若已有 AOSP 或 ACK 树，将以下目录复制到本机（例如内核源码上一级）：

- 源路径：`<AOSP>/prebuilts/clang/host/linux-x86/clang-r487747c`
- 目标：`<内核源码>/../prebuilts/clang/host/linux-x86/clang-r487747c`

或只克隆 clang 预编译仓库（体积较大）：

```bash
cd /path/to/parent/of/kernel
git clone --depth 1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
# 然后设置环境变量后构建（见下）
export PREBUILTS_ROOT=/path/to/parent/of/kernel/linux-x86
```

**方式 B：使用 kernel/build 工作区（需 prebuilts）**

使用 `build_wsl.sh` 时，将 prebuilts 放到工作区内：

- 工作区目录：`<内核源码>/../kernel_build_ws`
- 需要存在：`kernel_build_ws/prebuilts/clang/host/linux-x86/clang-r487747c/`

## 3. 构建方式

### 方式一：独立脚本（推荐，不依赖 kernel/build）

在内核源码根目录执行：

```bash
# 若 prebuilts 在默认位置：../prebuilts/clang/host/linux-x86/clang-r487747c
./build_wsl_standalone.sh

# 或指定 prebuilts 根（若 clone 了 linux-x86 仓库到 /path/to/linux-x86）
PREBUILTS_ROOT=/path/to/linux-x86 ./build_wsl_standalone.sh

# 或直接指定 clang 的 bin 目录
CLANG_BIN=/path/to/clang-r487747c/bin ./build_wsl_standalone.sh
```

输出目录默认：`./out`。产物包括：

- `out/arch/arm64/boot/Image`
- `out/arch/arm64/boot/Image.gz`
- `out/arch/arm64/boot/Image.lz4`

### 方式二：使用 kernel/build（需完整 prebuilts + build-tools）

```bash
./build_wsl.sh
```

会使用 `../kernel_build_ws`，并调用 `build/build.sh`。当前 kernel/build 的 main 分支以 Bazel/Kleaf 为主，若缺少传统 `build.sh`，请用方式一。

## 4. 使用清华镜像拉取（repo sync）

若直连 android.googlesource.com 失败，可按 [TUNA AOSP 镜像说明](https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/) 使用镜像。脚本已支持：设置 **镜像根** 后，会用 `git config url.<镜像>/.insteadof https://android.googlesource.com/`，repo 仍用标准 URL，所有拉取走镜像。

```bash
# 删除旧 .repo 后，用清华镜像拉取并构建
rm -rf ~/kernel_aosp_ws/.repo
export KERNEL_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/git/AOSP
cd /path/to/android_16.0_kernel_MT6989
./scripts/aosp_kernel_sync_and_build.sh
```

**拉取体积（仅供参考）**：

- **完整 AOSP**（platform/manifest）：约 **850GB**（见 TUNA 文档「建立次级镜像」）。
- **仅 kernel manifest**（kernel/manifest + common + build + prebuilts）：约 **20～50GB**，视分支和 prebuilts 而定；其中 prebuilts/clang 占比较大。本脚本使用 `repo sync -c -j4`，TUNA 建议并发不宜过高以免 503。

## 5. 后续：打包与测试

用 `device_extract/imgread` 中的 magiskboot 和 `Documentation/android/vivo_mt6989_boot_repack.txt` 中的参数打包 boot 镜像，并**先用 `fastboot boot` 临时引导测试**，勿直接 `fastboot flash boot`。
