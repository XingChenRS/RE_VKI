# Android 16.0 内核 (MT6989 / GKI) — 官方源码补全与本地构建参考

> **重要说明**  
> 本仓库**仅对官方 kernel 源码做补全**（头文件、Makefile、脚本等），使能在本地 WSL 环境完成编译。  
> **当前状态：能在本地 WSL 环境编译通过，但刷入后几乎无法正常启动。**  
> **本仓库内容仅供参考**，不保证任何设备可启动或数据安全，请勿依赖其产物直接刷机。

基于 **MT6989**（联发科）的 Android 16.0 GKI 内核源码，在 **WSL (x86_64)** 下使用实机提取的 config/DTB 与 AOSP Clang 可完成构建；修改仅用于在 WSL 中通过编译，不解决启动兼容性。

---

## 资料说明

本仓库将**文档**与**设备提取文件**分类存放，便于查阅与复现。

### 文档（`docs/`）

| 文件 | 说明 |
|------|------|
| [docs/BUILD_REPRODUCE.md](docs/BUILD_REPRODUCE.md) | **构建与复现**：在 WSL 中复现编译的完整步骤，含环境、依赖、AOSP Clang、实机提取数据说明（含为何剔除部分 CONFIG）、构建步骤、产物、故障排除、Image 体积说明；并含「其他构建方式」如 `build_vivo_local.sh`。**仅编译可复现，刷机几乎无法启动。** |
| [docs/BUILD_FIXES_LOG.md](docs/BUILD_FIXES_LOG.md) | **修复日志**：在 WSL 下编译时遇到的所有问题、原因与修改说明（模块签名、netfilter 头文件/符号、BTF、lz4 等），以及 Image 比官方小约 10MB 的原因与可选恢复方式。 |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | **变更与探索记录**：当前版本信息（内核/实机 config 版本、构建环境、产物、**启动状态**）、探索过程中的失败与修复列表、此前已存在的修改、文档与脚本版本对应关系。 |

上述文档仅描述如何在 WSL 中复现**编译**，不保证刷入后能正常启动；**本仓库内容仅供参考。**

### 设备提取文件（`device_extract/vivo_x100pro/`）

| 内容 | 说明 |
|------|------|
| **device_extract/vivo_x100pro/** | **Vivo X100 Pro (MT6989 / V2324HA)** 实机提取文件单独存放目录。内含 `02_kernel_config/running_kernel.config`、`04_device_tree/fdt.dtb` 及提取时的附加信息（系统信息、模块列表、安全/分区等）。构建脚本 **优先** 使用本目录；若无则回退到 `device_extract/extracted_*/`。 |
| device_extract/vivo_x100pro/README.txt | 本目录说明与构建所需文件列表。 |

其他目录（如 `device_extract/dtc/`、`device_extract/ko_modules/`）为工具或其它用途，见各自目录内说明。  
实机提取数据在构建中的用法详见 [docs/BUILD_REPRODUCE.md](docs/BUILD_REPRODUCE.md) 第 4 节；原 [device_extract/README_DEVICE_BUILD.md](device_extract/README_DEVICE_BUILD.md) 已改为指向上述文档。

---

## 快速开始

### 环境要求

- **WSL2**（Ubuntu 20.04+ 推荐）或 Linux x86_64
- **AOSP Clang**：将 `linux-x86` 版放在仓库**上级目录**，例如  
  `../aospclang/linux-x86/clang-r547379/bin`（或设置 `CLANG_PATH`）
- 交叉编译：`aarch64-linux-gnu-gcc`（`gcc-aarch64-linux-gnu`）
- 实机提取数据：使用仓库自带的 `device_extract/vivo_x100pro/`（或 `device_extract/extracted_*/`）即可

### 一键构建（WSL 下在仓库根目录执行）

```bash
chmod +x build_with_device_extract.sh
./build_with_device_extract.sh
```

产物：`out/arch/arm64/boot/Image`、`Image.gz`（若已安装 `lz4` 则还有 `Image.lz4`）、`out/device_dtb/fdt.dtb` 以及各模块 `.ko`。  
**当前刷入后几乎无法正常启动，本仓库仅供编译与参考，请勿依赖其产物刷机。**

若在 **Windows 编辑、在 WSL 其他路径编译**，需先运行 `sync_modified_to_wsl.sh` 再执行上述构建脚本。详见 [docs/BUILD_REPRODUCE.md](docs/BUILD_REPRODUCE.md)。

---

## 关于构建出的 Image 比官方内核小约 10MB

本仓库默认构建产出的 **Image 体积比官方/实机内核小约 10MB**，主要原因：脚本关闭了 `CONFIG_DEBUG_INFO_BTF`（不嵌入 BTF）。若希望体积更接近或需要 BTF，见 [docs/BUILD_FIXES_LOG.md](docs/BUILD_FIXES_LOG.md) 中「关于构建出的 Image 比官方小约 10MB」及第 8 条。

---

## 许可证与免责

内核源码遵循其原有许可证（如 GPL-2.0）。  
**本仓库仅对官方 kernel 源码做补全，当前状态为能在本地 WSL 环境编译，但几乎无法正常启动。本仓库内容仅供参考。** 使用本仓库产物刷机存在变砖或数据丢失风险，请勿依赖本仓库做任何刷机决策。
