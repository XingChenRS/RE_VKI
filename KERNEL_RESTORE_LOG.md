# vivo X100 Pro 内核源码还原工作日志

## 项目概述
- **目标设备**: vivo X100 Pro
- **SoC**: MediaTek 天玑 9300 (MT6985/MT6989)
- **系统版本**: Android 15 (OriginOS 5)
- **Root 方式**: Magisk
- **Bootloader**: 已解锁
- **基础源码**: Android GKI 6.1.145 (android14-6.1 分支)
- **最终目标**: 编译出可刷入的自定义内核（去除反 root 机制）

---

## 源码现状分析

### 已有内容
- 完整的 Linux 6.1.145 内核源码树（Android Common Kernel）
- GKI 构建配置文件 (build.config.*)
- vivo ABI 符号列表 (`android/abi_gki_aarch64_vivo`，5236 个符号)
- 标准 MediaTek 驱动框架（但仅覆盖到 MT8195，不含 MT6985/MT6989）
- GKI 模块保护机制 (`CONFIG_MODULE_SIG_PROTECT`)
- 标准安全框架（dm-verity, fs-verity, SELinux, LoadPin 等）

### 已知缺失
1. **`kernel/vivo_rsc/`** — Kconfig 和 kernel/Makefile 中引用 `CONFIG_VIVO_RSC`，但目录不存在
2. **MT6985/MT6989 设备树** — `arch/arm64/boot/dts/mediatek/` 中无对应 DTS/DTSI
3. **MT6985/MT6989 时钟驱动** — `drivers/clk/mediatek/` 中无对应文件
4. **MT6985/MT6989 pinctrl 驱动** — `drivers/pinctrl/mediatek/` 中无对应文件
5. **MT6985/MT6989 音频驱动** — `sound/soc/mediatek/` 中无对应目录
6. **MT6985/MT6989 GPU 驱动** — 无 Mali/IMG GPU 驱动
7. **所有 vivo 私有模块** — 无任何 vivo 定制模块源码
8. **MediaTek 互联驱动** — `drivers/interconnect/` 中无 MediaTek 支持
9. **设备专用 defconfig** — 无 MT6985/vivo X100 Pro 的配置文件

### 安全机制识别（源码中已发现）
- `CONFIG_MODULE_SIG_PROTECT=y` — GKI 模块签名保护
- `CONFIG_DM_VERITY=y` + `CONFIG_DM_VERITY_FEC=y` — dm-verity 分区校验
- `CONFIG_FS_VERITY=y` — 文件级完整性校验
- `CONFIG_MODULE_SIG=y` — 内核模块签名
- LoadPin LSM — 模块/固件加载源固定
- Lockdown LSM — 内核锁定

---

## 阶段一：设备信息提取

### 步骤 1.0 — 生成提取脚本
- **时间**: 2026-02-07
- **操作**: 创建设备信息提取脚本
- **产出文件**:
  - `device_extract/extract_all.sh` — Linux/Mac 全量提取脚本
  - `device_extract/extract_all_win.bat` — Windows 全量提取脚本
  - `device_extract/quick_check.bat` — 快速检查 ADB 连接和 root 权限
- **状态**: [已完成]

### 步骤 1.1 — 用户执行提取脚本（已完成）
- **时间**: 2026-02-07
- **操作**: 用户重写 sh 脚本并在设备上以 su 直接运行
- **提取结果目录**: `device_extract/extracted_20260207_024006`
- **状态**: [已完成]

### 提取结果摘要（extracted_20260207_024006）

| 项目 | 结果 |
|------|------|
| 设备型号 | V2324HA (vivo X100 Pro) |
| 运行中内核版本 | **6.1.124**-android14-11-maybe-dirty |
| 源码树内核版本 | 6.1.145（存在小版本差） |
| 编译器 | Clang 17.0.2 (based on r487747c) |
| SoC / 设备树 model | **MT6989** |
| 设备树 compatible | mediatek,MT6989 |
| config.gz | 已提取，已解压为 running_kernel.config |
| fdt.dtb | 已提取 |
| kallsyms | 已提取，427602 行；kallsyms_unmasked.txt 含真实地址 |
| 模块 | 347 个 .ko（脚本仅处理前 100 个的 modinfo） |
| 模块路径 | 主要在 /vendor_dlkm/lib/modules/ |
| CONFIG 行数 | 运行约 3018 行 vs gki_defconfig 约 668 行 |

### 运行中内核 cmdline（关键片段）
```
console=tty0 root=/dev/ram ... firmware_class.path=/vendor/firmware ...
product.version=PD2324_A_15.1.9.55.W10 ... ramoops.mem_address=0x48090000 ...
vivoboot.bootreason=reboot vivolog_flag=0 ... bootconfig
```

### 安全状态（设备当前）
- ro.boot.verifiedbootstate = green
- ro.boot.vbmeta.device_state = locked
- SELinux = Enforcing
- kptr_restrict = 2（默认遮蔽 kallsyms 地址；脚本已生成 kallsyms_unmasked.txt）

### 关键发现：vivo 私有配置与模块
- **CONFIG_MODULE_SIG_PROTECT**: 设备为 **未启用**（`# CONFIG_MODULE_SIG_PROTECT is not set`），源码树 gki_defconfig 为启用。自定义内核若需加载未签名 vendor 模块，应保持关闭。
- **CONFIG_VIVO_RSC=y**、**CONFIG_VIVO_RSC_FAKE=y** 等大量 CONFIG_VIVO_* 存在于运行配置；源码中 `kernel/vivo_rsc/` 目录缺失，实际 **vivo_rsc** 以 .ko 形式存在于 vendor_dlkm 并已加载。
- 运行配置使用 **CONFIG_MODULE_SIG_KEY="$(DEVICE_MODULES_REL_DIR)/certs/mtk_signing_key.pem"**（MediaTek 签名密钥）。
- 已加载的 vivo 相关模块（lsmod）：vivo_ts, vivo_haptic_core, vivo_audio_ktv, vivo_soc_codec, vivo_codec_common_node, vivo_fs_trace, dm_verity_fec_vivo, **vivo_rsc**, vivo_tshell, vivo_board_info, vivo_board_info_detect, vivo_display, vivo_bsp_engine 等。

### 需要从设备提取的关键数据清单

| 编号 | 数据 | 来源 | 重要性 | 用途 |
|------|------|------|--------|------|
| 1 | config.gz | /proc/config.gz | **极高** | 生成准确的 defconfig |
| 2 | 设备树 FDT | /sys/firmware/fdt | **极高** | 补全设备树源码 |
| 3 | 内核模块 .ko | /vendor/lib/modules/ 等 | **高** | 保持模块兼容性 |
| 4 | boot.img 结构 | boot 分区 | **高** | 打包时格式匹配 |
| 5 | kallsyms | /proc/kallsyms | **高** | 分析内核符号和函数 |
| 6 | dmesg 日志 | dmesg | **中** | 分析启动流程和安全机制 |
| 7 | DTBO 镜像 | dtbo 分区 | **中** | 设备树覆盖层分析 |
| 8 | vbmeta 镜像 | vbmeta 分区 | **中** | 分析 AVB 验证 |
| 9 | 安全属性 | getprop | **中** | 了解安全机制状态 |
| 10 | 分区布局 | /dev/block/by-name | **低** | 了解设备分区结构 |

---

## 阶段二：数据分析与信息整理

### 步骤 2.1 — config 对比分析
- **时间**: 2026-02-07
- **操作**: 对比 `running_kernel.config` 与 `arch/arm64/configs/gki_defconfig`
- **数据**: 运行配置约 3018 个 CONFIG_ 项，gki_defconfig 约 668 项。运行配置包含全部 GKI 所需项 + MediaTek/vivo 扩展。
- **策略**: 以运行配置为基准生成设备 defconfig 时，需剔除：(1) 源码中不存在的 Kconfig（如所有 CONFIG_VIVO_* 对应源码缺失的）、(2) 签名路径等构建时变量、(3) 可选关闭的安全验证项以便自定义内核。
- **产出**: 见 `device_extract/extracted_20260207_024006/02_kernel_config/CONFIG_VIVO_and_related_options.txt`（VIVO 相关选项清单）
- **状态**: [进行中]

### 步骤 2.2 — Boot 镜像分析
- **说明**: 用户已备份 boot.img 和 init_boot.img。后续打包需与官方格式一致。
- **建议**: 使用 magiskboot 或 unpackbootimg 解包用户提供的 boot.img，记录 header 版本、page size、kernel/ramdisk offset、cmdline、kernel 压缩格式（Image.gz / Image.lz4）。
- **状态**: [待用户提供 boot.img 路径或自行解包后补充]

### 步骤 2.3 — 设备树 DTB 反编译
- **输入**: `device_extract/extracted_20260207_024006/04_device_tree/fdt.dtb`
- **命令**: `dtc -I dtb -O dts -o fdt.dts fdt.dtb`（需安装 dtc 工具）
- **用途**: 反编译得到的 DTS 可作为补全 `arch/arm64/boot/dts/mediatek/` 下 MT6989 设备树的基础。
- **状态**: [待执行或由接手者执行；详见 device_extract/README_ANALYSIS_AND_BUILD.md]

---

## 阶段三：源码补全与配置（已完成）

### 步骤 3.1 — 移除 vivo_rsc 引用
- **时间**: 2026-02-07
- **修改**:
  - **kernel/Makefile**：注释掉 `obj-$(CONFIG_VIVO_RSC) += vivo_rsc/`，避免编译不存在的 `kernel/vivo_rsc/` 目录。
  - **Kconfig**：注释掉 `source "kernel/vivo_rsc/Kconfig"`，避免 Kconfig 解析失败。
- **说明**: 设备上 vivo_rsc 由 vendor_dlkm 中的 .ko 提供，无需内核内建。
- **状态**: [已完成]

### 步骤 3.2 — 可恢复/自定义内核配置片段与构建入口
- **新增文件**:
  - `arch/arm64/configs/vivo_restore_gki.fragment`：仅一行 `# CONFIG_MODULE_SIG_PROTECT is not set`。
  - `build.config.gki.aarch64.vivo_restore`：在 gki_defconfig 基础上用 merge_config.sh 合并上述 fragment，生成 vivo_restore_gki_defconfig 并编译。
- **使用**: 构建时指定 `BUILD_CONFIG=build.config.gki.aarch64.vivo_restore`（在 AOSP/ACK 内核构建环境中）。
- **状态**: [已完成]

### 步骤 3.3 — 设备树与 defconfig 说明
- **设备树**: 当前源码树无 MT6989 DTS；需用提取的 `fdt.dtb` 反编译为 DTS 后，再按需拆分为内核树所需 DTS/DTSI。详见 `device_extract/README_ANALYSIS_AND_BUILD.md`。
- **Defconfig**: 不建议直接使用 running_kernel.config 作为 .config（含大量无源码的 CONFIG_VIVO_*）。应以 gki_defconfig 为基 + 上述 fragment；若需 MT6989 专用选项，仅合并源码中**已存在**的 Kconfig 项。
- **状态**: [已文档化]

---

## 阶段四：编译与测试

### 步骤 4.1 — 编译环境
- **要求**: Android GKI 构建环境（Clang r487747c / 17.0.2，与设备 /proc/version 一致）、交叉编译 aarch64。
- **参考**: 源码根目录 `build.config.*`，主入口为 `build.config.gki.aarch64`；需在 AOSP 或 ACK 官方推荐环境中执行构建。
- **状态**: [待用户在本机搭建环境后执行]

### 步骤 4.2 — 构建命令要点
- 使用 **gki_defconfig** + **vivo_restore_gki.fragment** 生成 .config 并编译。
- 产物关注：`arch/arm64/boot/Image.lz4` 或 `Image.gz`（需与原始 boot 中 kernel 压缩格式一致）。

### 步骤 4.3 — Boot 镜像打包与测试
- 使用 magiskboot 或 mkbootimg，按**用户已备份的 boot.img** 的 header/offset/cmdline 打包新 kernel。
- **首次必须**使用 `fastboot boot 新boot.img` 临时引导，确认能启动后再考虑 `fastboot flash boot`。
- **状态**: [待用户执行]

---

## 总结与接手者说明

### 已完成事项
1. **阶段一**：设备信息已提取至 `device_extract/extracted_20260207_024006/`（config.gz、fdt.dtb、kallsyms、模块列表、安全信息等）。
2. **阶段二**：已分析运行配置与 gki_defconfig 差异，并整理 VIVO 相关 CONFIG 清单；设备树反编译与 boot 解包步骤已文档化。
3. **阶段三**：已移除源码中对缺失目录 `kernel/vivo_rsc/` 的引用（kernel/Makefile、Kconfig）；已添加 vivo_restore_gki.fragment 与 build.config.gki.aarch64.vivo_restore。
4. **阶段四**：构建步骤与注意事项已写入 `device_extract/README_ANALYSIS_AND_BUILD.md`；实际编译、打包与 fastboot 测试需在本机由用户完成。

### 关键文件索引
| 用途 | 路径 |
|------|------|
| 工作日志 | `KERNEL_RESTORE_LOG.md`（本文件） |
| **缺失/不确定/异常清单** | **`device_extract/GAPS_AND_UNCERTAINTIES.md`** |
| **vivo_rsc 移除影响说明** | **`device_extract/VIVO_RSC_REMOVAL_IMPACT.md`** |
| 提取数据 | `device_extract/extracted_20260207_024006/` |
| 镜像解包与 .ko | `device_extract/imgread/`、`device_extract/ko_modules/` |
| Boot 格式与 DTC 脚本 | `device_extract/imgread/log.txt`、`device_extract/run_dtc_decompile.bat` |
| **Boot 重打包参数（内核树内）** | **`Documentation/android/vivo_mt6989_boot_repack.txt`** |
| dtc 源码与说明 | `device_extract/dtc/`（dgibson/dtc 克隆）、`device_extract/dtc/README_DTC_BUILD.txt` |
| 分析与构建说明 | `device_extract/README_ANALYSIS_AND_BUILD.md` |
| 运行中内核配置 | `device_extract/.../02_kernel_config/running_kernel.config` |
| VIVO 选项清单 | `device_extract/.../02_kernel_config/CONFIG_VIVO_and_related_options.txt` |
| 设备树二进制 | `device_extract/.../04_device_tree/fdt.dtb` |
| 自定义 GKI 构建 | `BUILD_CONFIG=build.config.gki.aarch64.vivo_restore` |

### 需补充与潜在错误（详见 GAPS_AND_UNCERTAINTIES.md）
- **dtc**：本机未安装；安装 dtc 后运行 `device_extract/run_dtc_decompile.bat` 可生成 DTS。
- **vivo_rsc.ko**：未出现在 `ko_modules/` 中，若需分析需从设备单独拉取。
- **dtbo**：magiskboot unpack dtbo_b.img 发生段错误，未解包成功。
- **反 root 模块**：部分在 vendor_boot ramdisk，部分在 kernel 内；编译时需针对性处理。

---

## 2026-02-07 后续补充（复盘用）

### 1. DTB 反编译与 dtc

- **结论**：可使用 [dgibson/dtc](https://github.com/dgibson/dtc) 完成 DTB→DTS 反编译，工具正确。
- **已做**：
  - 已克隆 dgibson/dtc 至 `device_extract/dtc/`。
  - 本机已安装 GnuWin32 Make（winget install GnuWin32.Make）。
  - 在 `device_extract/dtc` 中执行 make 失败：缺少 C 编译器（cc）、bison、flex，Windows 默认无此环境。
- **当前**：未能在本机从源码构建 dtc。反编译脚本 `run_dtc_decompile.bat` 已支持：优先使用 `device_extract/dtc/dtc.exe`（若存在），否则使用 PATH 中的 dtc。
- **建议**：在 MSYS2 下执行 `pacman -S dtc`，或将已构建的 dtc 放入 `device_extract/dtc/`，再运行 `run_dtc_decompile.bat`；输出在 `device_extract/dts_output/`。
- **文档**：`device_extract/dtc/README_DTC_BUILD.txt` 已说明构建依赖与推荐用法。

### 2. DTBO 是否必须

- **结论**：**不是启动必需**。仅替换 boot 内 kernel、不动 vendor_boot/ramdisk 时，通常不需要动 DTBO。
- **说明**：DTBO 用于在基础 DTB 上叠加设备树片段（如板级差异）。当前设备主 DTB 来自 vendor_boot（DTB_SZ 447258），boot 分区内 kernel 可能自带或与 vendor_boot DTB 配合。若自编译内核使用与官方一致的 DTB 来源（如沿用 vendor_boot 的 DTB），可不解包/不修改 DTBO；仅在需要改设备树覆盖内容时才必须解包 DTBO。
- **现状**：magiskboot 解包 dtbo_b.img 段错误，DTBO 未解包成功；后续若需 DTBO 可用其他工具（如 AOSP dtboimg 或 abootimg）处理。

### 3. 反 su / 反 root 模块排查前提

- **结论**：反 su 模块的**具体定位与排查**，必须在以下条件满足后再做，否则无法可靠观察与复现：
  1. **自编译内核已能正常启动**（至少 `fastboot boot` 可进系统），且  
  2. **具备 dmesg 权限**（例如通过自编内核放开 dmesg_restrict/kptr_restrict，或 root 后查看），或  
  3. **KernelSU 已在 GKI 模式下成功运行**，便于从用户态/内核态同时观察。
- **原因**：反 root 逻辑多在内核或 vendor 模块中，需通过 dmesg、KernelSU 日志或内核符号/调用关系分析；在未取得上述环境前，无法准确区分“启动失败”与“反 root 拦截”。
- **已记入**：本前提已写入本文档与 `device_extract/GAPS_AND_UNCERTAINTIES.md`，便于后续在自编内核 + dmesg/KernelSU 就绪后再做反 su 排查。

### 4. 根据收集数据对内核源码的补充与改动（为后续编译做准备）

- **已有改动（保持）**：
  - 注释 `kernel/Makefile` 中对 `kernel/vivo_rsc/` 的编译。
  - 注释根目录 `Kconfig` 中对 `kernel/vivo_rsc/Kconfig` 的引用。
  - 新增 `arch/arm64/configs/vivo_restore_gki.fragment`（关闭 CONFIG_MODULE_SIG_PROTECT）。
  - 新增 `build.config.gki.aarch64.vivo_restore`（合并 gki_defconfig + 上述 fragment）。
- **本次新增**：
  - **Documentation/android/vivo_mt6989_boot_repack.txt**：从 `device_extract/imgread` 解包结果整理的 boot/vendor_boot 参数（HEADER_VER、PAGESIZE、KERNEL_FMT、CMDLINE 等），供重打包 boot 镜像时与官方格式一致，便于复盘与接手者使用。
- **未改**：未直接合并 `running_kernel.config` 中 CONFIG_VIVO_*（无对应源码）；未新增 MT6989 DTS（需 DTB 反编译后再整理）；设备树仍使用提取的 fdt.dtb。**后续**：dtc 已在本机编译并完成 DTB→DTS 反编译（见下）。

### 5. dtc 编译与 DTB 反编译（2026-02-07 续）

- **目标**：使用 [dgibson/dtc](https://github.com/dgibson/dtc) 在本机（Windows）编译 dtc，并将提取的 DTB 反编译为 DTS。
- **环境**：
  - 已安装：WinFlexBison（win_bison/win_flex）、WinLibs MinGW64（gcc）、GnuWin32 Make、Git（uname/sed 等）、Meson + Ninja（pip）。
  - 在 `device_extract/dtc` 使用 **Meson** 构建（Make 在 Git sh 下 CC 路径异常，故改用 Meson）。
- **操作**：
  1. 在 `device_extract/dtc/host_bin/` 下新增 `flex.cmd`、`bison.cmd`，转发到 WinFlexBison 的 win_flex.exe / win_bison.exe，供 Meson 检测到 flex/bison。
  2. PATH 中加入 WinLibs 的 mingw64/bin、WinFlexBison 目录、host_bin；执行 `meson setup builddir -Dpython=disabled -Dyaml=disabled -Dvalgrind=disabled`，再 `meson compile -C builddir`。
  3. 将生成的 `builddir/dtc.exe` 复制为 `device_extract/dtc/dtc.exe`。
  4. 运行 `device_extract/run_dtc_decompile.bat`，对 `extracted_20260207_024006/04_device_tree/fdt.dtb` 和（若存在）`imgread/dtb` 反编译。
- **结果**：
  - **dtc.exe**：已生成于 `device_extract/dtc/dtc.exe`（及 builddir 内）。
  - **DTS 输出**：`device_extract/dts_output/fdt_from_sys_firmware.dts`（来自 /sys/firmware/fdt 的 fdt.dtb）。反编译过程有若干 dtc 告警（reg_format、unit_address_vs_reg 等），属常见情况，DTS 已生成可用。
- **后续**：可将 `dts_output/fdt_from_sys_firmware.dts` 整理为内核树中的 `arch/arm64/boot/dts/mediatek/` 设备树源文件（需拆分/包含 DTSI、与 defconfig 配合）；内核构建时设备树会一并编译。

### 6. 内核源码构建说明（阶段四入口）

- **构建系统**：本内核树为 Android GKI 风格，需在 **AOSP 或 ACK（Android Common Kernel）** 构建环境中执行，依赖：
  - `ROOT_DIR` / `KERNEL_DIR` 由构建脚本设置；
  - 预置工具链：`prebuilts/clang/host/linux-x86/clang-r487747c`（见 build.config.constants）；
  - 构建脚本通常为仓库顶层的 `build.sh` 或 `build/build.sh`（本 tar 内未包含，需使用官方 ACK 或 AOSP 内核构建流程）。
- **本仓库内已就绪**：
  - `BUILD_CONFIG=build.config.gki.aarch64.vivo_restore`：合并 gki_defconfig 与 vivo_restore_gki.fragment（关闭 CONFIG_MODULE_SIG_PROTECT），生成 `vivo_restore_gki_defconfig` 并编译。
  - 编译产物预期包含：`arch/arm64/boot/Image.lz4`、`Image.gz` 等（见 build.config.gki.aarch64）。
- **WSL 构建（2026-02-07 补充）**：
  - 已添加 **`build_wsl_standalone.sh`**：不依赖 kernel/build 仓库，仅需 Android clang（r487747c）与 WSL 下 make/flex/bison 等。脚本会合并 gki_defconfig + vivo_restore_gki.fragment 生成 .config，再执行 `make Image Image.gz Image.lz4 modules`。用法见 **`Documentation/android/WSL_BUILD.md`**。
  - 已添加 **`build_wsl.sh`**：会克隆 kernel/build 并链接 `common` 到本内核树，需在工作区内提供 `prebuilts/clang/host/linux-x86/clang-r487747c`；当前 kernel/build main 分支以 Bazel 为主，传统 make 入口可能缺失，建议优先用 `build_wsl_standalone.sh`。
  - 在 WSL 中需先安装：`sudo apt install build-essential libncurses-dev flex bison libssl-dev bc`；clang 需从 AOSP prebuilts 复制或 clone `platform/prebuilts/clang/host/linux-x86` 后指定 `PREBUILTS_ROOT`。
- **操作建议**：将本内核树置于 ACK 或 AOSP 内核仓库中，或通过构建脚本指定本目录为 `KERNEL_DIR`；设置 `BUILD_CONFIG=build.config.gki.aarch64.vivo_restore` 后执行该仓库的 build.sh。若在 Windows 上构建，使用 **WSL** 并按 `Documentation/android/WSL_BUILD.md` 执行。

### 7. AOSP kernel repo 拉取尝试（2026-02-07）

- **目的**：在 WSL 中通过 repo 拉取 AOSP kernel manifest，以便用官方 kernel/build 与本内核树一起编译。
- **执行**：运行 `scripts/aosp_kernel_sync_and_build.sh`（KERNEL_WS=/home/xingc/kernel_aosp_ws，KERNEL_SRC 指向本内核树）。
- **结果**：**repo init 失败**。错误为 `fatal: cannot obtain manifest https://android.googlesource.com/kernel/manifest` 及 `fatal: couldn't find remote ref refs/heads/android14-6.1`，属网络无法访问 android.googlesource.com（超时或环境限制）。
- **已做修改**：
  - 构建脚本支持通过环境变量 **`KERNEL_MIRROR`** 使用镜像：例如 `export KERNEL_MIRROR=https://aosp.tuna.tsinghua.edu.cn/kernel/manifest` 后再运行脚本（具体镜像地址需自行确认 TUNA 等是否提供 kernel manifest）。
  - 详细输出见 **`AOSP_KERNEL_BUILD_LOG.txt`**。
- **后续建议**：
  1. 使用镜像：在可访问的镜像站确认 kernel manifest 地址与分支名后，设置 `KERNEL_MIRROR` 重新执行 `aosp_kernel_sync_and_build.sh`。
  2. 或使用**独立构建**：不依赖 repo，直接使用 **`build_wsl_standalone.sh`**，仅需本机安装 clang（或从 AOSP prebuilts 复制 r487747c）及 make/flex/bison 等，见 `Documentation/android/WSL_BUILD.md`。

### 8. GitHub Actions 云端编译（2026-02-07）

- **目的**：不依赖本地 AOSP/repo 与镜像，用 GitHub Actions 在云端编译内核，可选集成 KernelSU。
- **已添加**：
  - **`.github/workflows/build-kernel.yml`**：单 job，checkout 本仓库 → 可选下载 AOSP clang → 可选运行 KernelSU `setup.sh` → 合并 `gki_defconfig` + `vivo_restore_gki.fragment` → `make Image Image.gz Image.lz4 modules` → 上传 Artifacts，手动运行时可选创建 Release。
  - **`Documentation/android/GITHUB_ACTIONS_BUILD.md`**：新建仓库、推送源码、启用 Actions、获取产物与打包刷机说明。
- **用法**：将本内核树推送到新 GitHub 仓库，在 Actions 页运行 “Build GKI Kernel”，从 Artifacts 下载 Image/Image.gz/Image.lz4；AOSP clang 下载失败时可勾选使用系统 clang。
- **参考**：KernelSU 官方 [how-to-build](https://kernelsu.org/guide/how-to-build.html)、[ChopinKernels/kernel-builder-chopin](https://github.com/ChopinKernels/kernel-builder-chopin)、[feicong/android-kernel-build-action](https://github.com/feicong/android-kernel-build-action)。

### 9. 日志与复盘

- 上述 1～8 已全部记入本日志；关键决策（dtc 用 dgibson/dtc、Meson 构建 dtc、DTBO 非必须、反 su 排查前提、新增 boot 重打包参考文档、内核构建需 AOSP/ACK 环境、repo 拉取失败与镜像/独立构建方案）均可在本段回溯。
- 若后续出现问题，可依据本段与 `GAPS_AND_UNCERTAINTIES.md` 逐项核对：dtc 与 DTS 输出（`device_extract/dtc/dtc.exe`、`device_extract/dts_output/`）、boot 参数是否与官方一致、是否在自编内核 + dmesg/KernelSU 后再做反 su 分析、内核构建是否在正确环境中使用 `BUILD_CONFIG=build.config.gki.aarch64.vivo_restore`；若用 repo，是否配置 `KERNEL_MIRROR` 或改用 `build_wsl_standalone.sh`。

