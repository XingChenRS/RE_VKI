# 在 WSL 中复现编译指南（MT6989 GKI）

> **重要**：本仓库**仅对官方 kernel 源码做补全**。**当前状态：能在本地 WSL 环境编译通过，但刷入后几乎无法正常启动。本仓库内容仅供参考。**

本文档描述如何在 **WSL (x86_64)** 或 Linux 下，从本仓库复现**内核编译**：环境、依赖、实机提取数据、构建步骤与故障排除。按顺序执行可得到与文档一致的**编译产物**；**该产物刷入设备后几乎无法正常启动，仅供学习与参考。**

---

## 1. 环境与版本（成功构建时）

| 项目 | 版本/说明 |
|------|-----------|
| 系统 | WSL2，Ubuntu 20.04+（或任意 x86_64 Linux） |
| 内核源码版本 | 6.1.145（Makefile 中 VERSION.PATCHLEVEL.SUBLEVEL） |
| 实机 config 来源 | 6.1.124-android14（设备 V2324HA 等） |
| 编译器 | AOSP Clang（推荐 r547379），仅用 Clang，不用系统 GCC 编内核 |
| 交叉工具链 | aarch64-linux-gnu-gcc（用于部分 host/脚本） |
| 构建日期（参考） | 2026-02-07 |

---

## 2. 依赖安装（WSL/Ubuntu）

```bash
sudo apt update
sudo apt install -y build-essential flex bison libssl-dev libelf-dev \
  bc cpio git kmod \
  gcc-aarch64-linux-gnu
```

可选（按需）：

- **BTF 支持**（体积会增大，与官方镜像更接近）：`sudo apt install dwarves`
- **Image.lz4**：`sudo apt install lz4`

---

## 3. AOSP Clang

- 从 [AOSP 预构建 Clang](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/) 下载对应版本（如 `clang-r547379`），解压到本仓库**上级目录**，例如：
  - 仓库：`/path/to/android_16.0_kernel_MT6989`
  - Clang：`/path/to/aospclang/linux-x86/clang-r547379/bin/clang`
- 或设置环境变量（在运行构建脚本前）：
  ```bash
  export CLANG_PATH="/path/to/aospclang/linux-x86/clang-r547379/bin"
  ```
- **注意**：必须在 **WSL 原生目录**（如 `/home/...`）或 Linux 原生路径下使用 Clang，避免在 `/mnt/c/` 下执行 ELF 导致 exec format 等问题。

---

## 4. 实机提取数据（用于与实机一致的 config + DTB）

构建脚本**优先**使用 `device_extract/vivo_x100pro/`，若无则使用 `device_extract/extracted_YYYYMMDD_HHMMSS/`。所需目录结构：

| 路径 | 说明 |
|------|------|
| `02_kernel_config/running_kernel.config` | 实机正在使用的内核配置（脚本会剔除 CONFIG_VIVO_* / RSC_* / VIVONET*） |
| `04_device_tree/fdt.dtb` | 实机设备树二进制；**当前刷入几乎无法启动，仅供参考。** |

**数据来源与用途**：config 作为 `.config` 使用，DTB 复制到 `out/device_dtb/fdt.dtb`。  
**为何剔除部分 CONFIG**：设备原厂启用了 `kernel/vivo_rsc` 等模块，对应大量 `CONFIG_VIVO_*`、`CONFIG_RSC_*`；当前源码树中已无 `kernel/vivo_rsc/`（Kconfig 已注释），若保留这些选项会导致配置/编译异常。剔除后与“无 vivo_rsc 的 GKI”一致，其余选项与实机一致。

若仓库已附带 `device_extract/vivo_x100pro/` 或 `device_extract/extracted_*/`，可直接进入第 5 步。若需自行提取，请将上述两个文件放入对应子目录。

---

## 5. 构建步骤

### 5.1 在 WSL 中直接于仓库根目录构建（推荐）

克隆或解压本仓库后，在**仓库根目录**执行：

```bash
cd /path/to/android_16.0_kernel_MT6989
chmod +x build_with_device_extract.sh
./build_with_device_extract.sh
```

**无需**运行 `sync_modified_to_wsl.sh`（该脚本用于「在 Windows 编辑、在 WSL 另一路径编译」的场景）。

### 5.2 在 Windows 编辑、在 WSL 其他路径编译时

若你在 Windows 下编辑源码，而在 WSL 的**另一目录**（如 `/home/user/kernel_build/...`）编译，需先将修改同步到该目录，再编译：

```bash
# 在 WSL 中执行，SCRIPT_DIR 为仓库在 /mnt/c/... 或 WSL 中的路径
export WSL_BUILD_DEST=/home/your_user/your_build_dir/android_16.0_kernel_MT6989
bash /path/to/android_16.0_kernel_MT6989/sync_modified_to_wsl.sh
cd "$WSL_BUILD_DEST"
./build_with_device_extract.sh
```

---

## 6. 构建产物

- `out/arch/arm64/boot/Image` — 未压缩内核镜像  
- `out/arch/arm64/boot/Image.gz` — Gzip 压缩  
- `out/arch/arm64/boot/Image.lz4` — 仅当已安装 `lz4` 时生成  
- `out/device_dtb/fdt.dtb` — **必须与上述 Image 一起用于打包 boot**  
- `out/**/*.ko` — 内核模块  

**当前刷入后几乎无法正常启动，本仓库仅供编译与参考，请勿依赖其产物刷机。**

---

## 7. 故障排除与修复记录

构建过程中若出现与文档中相同或类似的错误，请对照 [BUILD_FIXES_LOG.md](BUILD_FIXES_LOG.md) 逐条查看；所有已知问题及修复已写入该文件，并已体现在当前源码与脚本中。  
常见情况摘要：

- **模块签名密钥 / BTF / lz4**：脚本已自动处理（改用默认密钥、关闭 BTF、按需跳过 Image.lz4）。
- **netfilter 头文件或 .o 名**：已通过包装头与 Makefile 修正（区分大小写）。
- **vivo_rsc / kheaders**：Kconfig 与 kernel/Makefile 已注释或增加规则。

若你使用与文档一致的环境和实机提取数据，按上述步骤应能复现**编译**。**编译产物刷入后几乎无法正常启动，本仓库内容仅供参考。** 若仍有新报错，可将完整 make 输出保存后提 issue，并注明系统、Clang 路径与实机提取目录名。

---

## 8. 关于 Image 体积比官方小约 10MB

本仓库默认构建的 **Image 比官方/实机内核小约 10MB**，主要因为：

- **CONFIG_DEBUG_INFO_BTF=n**：脚本为免依赖 `pahole` 关闭了 BTF，内核中不嵌入 BTF，体积明显减小。
- 若需与官方体积更接近或需要 BTF（如 eBPF），请安装 `dwarves` 并在 `build_with_device_extract.sh` 中注释掉「关闭 BTF」的 sed/echo 行后重新构建。详见 [BUILD_FIXES_LOG.md](BUILD_FIXES_LOG.md) 第 8 条。

---

## 9. 其他构建方式（build_vivo_local.sh）

除 `build_with_device_extract.sh`（实机 config + DTB）外，仓库根目录还提供 `build_vivo_local.sh`：使用 `gki_defconfig` + `vivo_restore_gki.fragment` 进行构建，不依赖 `device_extract/vivo_x100pro/`。  
用法：在 WSL 中 `chmod +x build_vivo_local.sh` 后执行 `./build_vivo_local.sh`；若使用 AOSP Clang，可先 `export CLANG_PATH="/path/to/aospclang/linux-x86/clang-r547379/bin"`。  
**同样地，编译产物刷入后几乎无法正常启动，本仓库内容仅供参考。**
