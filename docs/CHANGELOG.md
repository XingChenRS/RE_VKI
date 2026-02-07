# 变更与构建探索日志

> **仓库说明**：本仓库**仅对官方 kernel 源码做补全**。**当前状态：能在本地 WSL 环境编译通过，但刷入后几乎无法正常启动。本仓库内容仅供参考。**

本文档记录从「实机 config + DTB + AOSP Clang 构建 MT6989 GKI 内核」的探索过程：**失败现象 → 修复 → 本地编译通过**。编译可复现，**刷机不可用**。

---

## 当前版本（仅编译可复现，刷入无法正常启动）

| 项目 | 值 |
|------|-----|
| 内核源码版本 | 6.1.145（VERSION=6, PATCHLEVEL=1, SUBLEVEL=145） |
| 实机 config 版本 | 6.1.124-android14-11-maybe-dirty（设备 V2324HA） |
| 构建环境 | WSL2 x86_64，AOSP Clang（r547379），仅用 Clang 编译 |
| 构建目标 | Image, Image.gz, modules（Image.lz4 可选，依赖 lz4 命令） |
| 构建日期（参考） | 2026-02-07 |
| 产物 | `out/arch/arm64/boot/Image`、`Image.gz`、`out/device_dtb/fdt.dtb`、各 `.ko` |
| **启动状态** | **刷入后几乎无法正常启动，仅供参考。** |

构建出的 Image 比官方内核小约 10MB，主要因默认关闭 BTF。详见 [BUILD_FIXES_LOG.md](BUILD_FIXES_LOG.md) 及 README「关于 Image 体积」。

---

## 探索过程：失败与修复

以下按构建顺序列出曾出现的失败及对应修复（详细技术说明见 [BUILD_FIXES_LOG.md](BUILD_FIXES_LOG.md)）。

### 1. 模块签名密钥不存在

- **失败**：`No rule to make target '/certs/mtk_signing_key.pem', needed by 'certs/signing_key.x509'`
- **修复**：在 `build_with_device_extract.sh` 中用 sed 将 `CONFIG_MODULE_SIG_KEY` 改为 `certs/signing_key.pem`。

### 2. net/netfilter：xt_TCPMSS.o 无规则

- **失败**：`No rule to make target 'net/netfilter/xt_TCPMSS.o'`
- **修复**：`net/netfilter/Makefile` 中 `xt_TCPMSS.o` 改为 `xt_tcpmss.o`（与源文件 `xt_tcpmss.c` 一致）。

### 3. xt_tcpmss.c 缺少 struct/宏

- **失败**：`incomplete definition of type 'struct xt_tcpmss_info'`、`undeclared identifier 'XT_TCPMSS_CLAMP_PMTU'`
- **修复**：在 `include/uapi/linux/netfilter/xt_TCPMSS.h` 中补充 `struct xt_tcpmss_info` 与 `#define XT_TCPMSS_CLAMP_PMTU 0xffff`。

### 4. net/netfilter：xt_dscp.o 无规则

- **失败**：`No rule to make target 'net/netfilter/xt_dscp.o'`
- **修复**：Makefile 中 MATCH_DSCP 由 `xt_dscp.o` 改为 `xt_DSCP.o`。

### 5. net/netfilter：xt_hl.o 无规则

- **失败**：`No rule to make target 'net/netfilter/xt_hl.o'`
- **修复**：Makefile 中 MATCH_HL 由 `xt_hl.o` 改为 `xt_HL.o`。

### 6. ip6t_hl.h 找不到

- **失败**：`fatal error: 'linux/netfilter_ipv6/ip6t_hl.h' file not found`
- **修复**：新增包装头 `include/uapi/linux/netfilter_ipv6/ip6t_hl.h`，内容 `#include <linux/netfilter_ipv6/ip6t_HL.h>`。

### 7. xt_HL.c：ipt_ttl_info / IPT_TTL_EQ 未定义

- **失败**：`incomplete definition of type 'struct ipt_ttl_info'`、`undeclared identifier 'IPT_TTL_EQ'`
- **修复**：在 `include/uapi/linux/netfilter_ipv4/ipt_ttl.h` 中补全 TTL match 的枚举与 `struct ipt_ttl_info`。

### 8. BTF 生成失败（pahole 不可用）

- **失败**：`pahole (pahole) is not available`、`Failed to generate BTF for vmlinux`
- **修复**：脚本中强制将 `CONFIG_DEBUG_INFO_BTF` 与 `CONFIG_DEBUG_INFO_BTF_MODULES` 置为 `n`；可选安装 dwarves 后注释相关行以恢复 BTF。

### 9. Image.lz4 构建失败（lz4 未安装）

- **失败**：`/bin/sh: 1: lz4: not found`
- **修复**：脚本中根据 `command -v lz4` 决定是否编译 Image.lz4；无 lz4 时仅编 Image、Image.gz、modules。

---

## 此前已存在的修改（非本次探索新发现）

- **Kconfig**：注释 `source "kernel/vivo_rsc/Kconfig"`（vivo_rsc 不在源码树）。
- **kernel/Makefile**：注释 `obj-$(CONFIG_VIVO_RSC) += vivo_rsc/`；为 O= 构建增加将 `kheaders_data.tar.xz` 拷到 `$(srctree)/kernel/` 的规则。
- **include/uapi/linux/netfilter/**：小写包装头（xt_dscp.h、xt_mark.h、xt_rateest.h）及 xt_connmark.h 补全，解决区分大小写与 visibility 问题。

---

## 文档与脚本版本（与当前构建对应）

- `build_with_device_extract.sh`：含 CONFIG 剔除、MODULE_SIG_KEY 替换、BTF 关闭、可选 Image.lz4、产物与 DTB 复制；优先使用 `device_extract/vivo_x100pro/`。
- `sync_modified_to_wsl.sh`：同步 netfilter 头、Makefile、Kconfig、构建脚本及 `docs/` 下文档至 WSL 指定目录。
- `docs/BUILD_FIXES_LOG.md`：上述 1–9 及既有修改的完整技术记录。
- `docs/BUILD_REPRODUCE.md`：在 WSL 中复现编译的步骤与故障排除。

以上版本与「当前版本」一致，按 [BUILD_REPRODUCE.md](BUILD_REPRODUCE.md) 操作可复现**编译**；**刷入后几乎无法正常启动，本仓库内容仅供参考。**
