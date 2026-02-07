# 内核构建修复日志 (WSL / 区分大小写 + 实机 config)

> **仓库说明**：本仓库**仅对官方 kernel 源码做补全**。**当前状态：能在本地 WSL 环境编译通过，但刷入后几乎无法正常启动。本仓库内容仅供参考。**

在 WSL (x86_64) 下使用实机提取的 config + DTB、AOSP Clang 编译 MT6989 GKI 内核时遇到的问题与修复记录；以下修改仅为保证在 WSL 中能完成编译，不解决刷机后的启动问题。

---

## 关于构建出的 Image 比官方小约 10MB

**现象**：本仓库默认构建的 `Image` 体积比官方/实机内核小约 **10MB**。

**主要原因**：

1. **BTF 关闭**：为避免依赖 `pahole`，构建脚本将 `CONFIG_DEBUG_INFO_BTF` 与 `CONFIG_DEBUG_INFO_BTF_MODULES` 设为 `n`，内核中不嵌入 BTF，体积明显减小（BTF 通常可占数 MB 到十数 MB）。
2. 若官方镜像还带有额外调试信息或符号，本构建未开启时也会产生差异。

**若需与官方体积更接近或需要 BTF**（如 eBPF 调试）：安装 `dwarves`（`sudo apt install dwarves`），并在 `build_with_device_extract.sh` 中注释掉「关闭 BTF」的 4 行（两处 sed + 两处 grep/echo），然后重新执行构建。

---

## 1. 模块签名密钥不存在

**现象：**
```text
make[3]: *** No rule to make target '/certs/mtk_signing_key.pem', needed by 'certs/signing_key.x509'.
```

**原因：** 实机 config 中 `CONFIG_MODULE_SIG_KEY="$(DEVICE_MODULES_REL_DIR)/certs/mtk_signing_key.pem"`，本地无此路径。

**修复：** 在 `build_with_device_extract.sh` 中，生成 `out/.config` 后用 sed 改为默认路径：
```bash
sed -i 's|^CONFIG_MODULE_SIG_KEY=.*|CONFIG_MODULE_SIG_KEY="certs/signing_key.pem"|' "$OUT_DIR/.config"
```

---

## 2. net/netfilter：xt_TCPMSS.o 无规则

**现象：**
```text
make[4]: *** No rule to make target 'net/netfilter/xt_TCPMSS.o', needed by 'net/netfilter/built-in.a'.
```

**原因：** 源文件为 `xt_tcpmss.c`（小写），生成 `xt_tcpmss.o`；Makefile 中写的是 `xt_TCPMSS.o`，在区分大小写的文件系统上不一致。

**修复：** `net/netfilter/Makefile` 中：
```makefile
obj-$(CONFIG_NETFILTER_XT_TARGET_TCPMSS) += xt_tcpmss.o
```

---

## 3. net/netfilter：xt_tcpmss.c 缺少 struct/宏定义

**现象：**
```text
error: incomplete definition of type 'const struct xt_tcpmss_info'
error: use of undeclared identifier 'XT_TCPMSS_CLAMP_PMTU'
```

**原因：** `include/uapi/linux/netfilter/xt_TCPMSS.h` 仅包含 match 的 `xt_tcpmss_match_info`，未定义 target 用的 `struct xt_tcpmss_info` 和 `XT_TCPMSS_CLAMP_PMTU`。

**修复：** 在 `xt_TCPMSS.h` 中补充：
```c
struct xt_tcpmss_info { __u16 mss; };
#define XT_TCPMSS_CLAMP_PMTU 0xffff
```

---

## 4. net/netfilter：xt_dscp.o 无规则

**现象：**
```text
make[4]: *** No rule to make target 'net/netfilter/xt_dscp.o', needed by 'net/netfilter/built-in.a'.
```

**原因：** 源码为 `xt_DSCP.c`，生成 `xt_DSCP.o`；Makefile 中 MATCH 项写的是 `xt_dscp.o`。

**修复：** `net/netfilter/Makefile` 中：
```makefile
obj-$(CONFIG_NETFILTER_XT_MATCH_DSCP) += xt_DSCP.o
```

---

## 5. net/netfilter：xt_hl.o 无规则

**现象：**
```text
make[4]: *** No rule to make target 'net/netfilter/xt_hl.o', needed by 'net/netfilter/built-in.a'.
```

**原因：** 源码为 `xt_HL.c`，生成 `xt_HL.o`；Makefile 中 MATCH 项写的是 `xt_hl.o`。

**修复：** `net/netfilter/Makefile` 中：
```makefile
obj-$(CONFIG_NETFILTER_XT_MATCH_HL) += xt_HL.o
```

---

## 6. net/netfilter：ip6t_hl.h 找不到 (xt_HL.c)

**现象：**
```text
../net/netfilter/xt_HL.c:17:10: fatal error: 'linux/netfilter_ipv6/ip6t_hl.h' file not found
```

**原因：** 源码包含小写 `ip6t_hl.h`，而 UAPI 中实际文件名为 `ip6t_HL.h`，在区分大小写的环境（如 WSL/Linux）下找不到。

**修复：** 新增小写包装头 `include/uapi/linux/netfilter_ipv6/ip6t_hl.h`，内容：
```c
#ifndef _IP6T_HL_H_WRAPPER
#define _IP6T_HL_H_WRAPPER
#include <linux/netfilter_ipv6/ip6t_HL.h>
#endif
```
同步脚本中增加对该头文件及 `netfilter_ipv6` 目录的同步。

---

## 7. xt_HL.c：struct ipt_ttl_info / IPT_TTL_EQ 等未定义

**现象：**
```text
error: incomplete definition of type 'const struct ipt_ttl_info'
error: use of undeclared identifier 'IPT_TTL_EQ'
```

**原因：** `include/uapi/linux/netfilter_ipv4/ipt_ttl.h` 仅包含 TTL target 的定义（`IPT_TTL_SET`/INC/DEC、`struct ipt_TTL_info`），缺少 TTL match 所需的 `struct ipt_ttl_info` 和 `IPT_TTL_EQ`/NE/LT/GT。

**修复：** 在 `ipt_ttl.h` 中补全 match 的枚举与结构体：将 match 枚举（`IPT_TTL_EQ`/NE/LT/GT）与原有 target 枚举合并为同一 enum（match 0–3，target 4–6），并增加 `struct ipt_ttl_info`（与 `ipt_TTL_info` 布局一致，供 match 使用）。同步脚本增加对 `include/uapi/linux/netfilter_ipv4/ipt_ttl.h` 的同步。

---

## 8. BTF 生成失败（pahole 不可用）

**现象：**
```text
BTF: .tmp_vmlinux.btf: pahole (pahole) is not available
Failed to generate BTF for vmlinux
Try to disable CONFIG_DEBUG_INFO_BTF
```

**原因：** 实机 config 可能开启 `CONFIG_DEBUG_INFO_BTF`，生成 BTF 需要安装 `pahole`（dwarves 包），本地未安装则构建失败。

**修复：** 在 `build_with_device_extract.sh` 中生成 `.config` 后强制关闭 BTF：
```bash
sed -i 's/^CONFIG_DEBUG_INFO_BTF=.*/CONFIG_DEBUG_INFO_BTF=n/' "$OUT_DIR/.config"
sed -i 's/^CONFIG_DEBUG_INFO_BTF_MODULES=.*/CONFIG_DEBUG_INFO_BTF_MODULES=n/' "$OUT_DIR/.config"
```
若已安装 `dwarves`（`sudo apt install dwarves`）且希望保留 BTF，可注释掉上述两行。

---

## 9. Image.lz4 构建失败（lz4 命令未安装）

**现象：**
```text
/bin/sh: 1: lz4: not found
make[2]: *** [../arch/arm64/boot/Makefile:31: arch/arm64/boot/Image.lz4] Error 127
```

**原因：** 生成 `Image.lz4` 需要系统安装 `lz4` 命令行工具，WSL 未安装则报错。

**修复：** 在 `build_with_device_extract.sh` 中根据是否可用 `lz4` 决定是否编译 Image.lz4：若 `command -v lz4` 存在则编译 `Image Image.gz Image.lz4 modules`，否则只编译 `Image Image.gz modules`。需要 Image.lz4 时可在 WSL 中执行 `sudo apt install lz4` 后重新运行脚本。

---

## 已存在的同类修复（此前对话）

- **include/uapi/linux/netfilter/** 小写包装头：`xt_dscp.h`→xt_DSCP.h，`xt_mark.h`→xt_MARK.h，`xt_rateest.h`→xt_RATEEST.h，`xt_connmark.h` 补全结构体与宏，解决 Ubuntu/AOSP Clang 下 visibility 与缺失定义问题。
- **Kconfig** 注释 `source "kernel/vivo_rsc/Kconfig"`；**kernel/Makefile** 注释 `obj-$(CONFIG_VIVO_RSC) += vivo_rsc/`，并为 O= 构建增加 `kheaders_data.tar.xz` 拷贝到 `$(srctree)/kernel/` 的规则。

---

## 同步脚本涉及文件

`sync_modified_to_wsl.sh` 当前会同步：

- `include/uapi/linux/netfilter/`：xt_connmark.h, xt_dscp.h, xt_mark.h, xt_rateest.h, xt_TCPMSS.h
- `include/uapi/linux/netfilter_ipv4/`：ipt_ttl.h
- `include/uapi/linux/netfilter_ipv6/`：ip6t_hl.h
- `kernel/Makefile`，`net/netfilter/Makefile`，`Kconfig`，`build_with_device_extract.sh`
- `docs/` 下文档（README.md、CHANGELOG.md、BUILD_FIXES_LOG.md、BUILD_REPRODUCE.md）

修改上述任意文件后，需在 WSL 中执行一次 `sync_modified_to_wsl.sh` 再编译。
