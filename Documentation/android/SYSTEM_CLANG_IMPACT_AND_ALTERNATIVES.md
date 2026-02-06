# 使用系统 Clang 的影响与可选方案

本仓库在 CI（GitHub Actions）中**不下载 AOSP Clang**（googlesource 子目录归档返回 400，整仓过大），采用 [mcxiaochenn/Action_OKI_KernelSU_SUSFS](https://github.com/mcxiaochenn/Action_OKI_KernelSU_SUSFS) 的思路，从 **apt.llvm.org** 安装 **LLVM 18**（clang-18、lld-18）作为固定工具链编译。以下说明可能影响及可选替代方案。

---

## 1. 不用 AOSP Clang 可能带来的影响

| 方面 | 说明 |
|------|------|
| **KMI/ABI** | 官方 GKI 使用 AOSP clang（如 r487747c）构建，保证与厂商模块的接口一致。用 LLVM 18 等非 AOSP 工具链（版本、优化选项不同）时，内核二进制在结构体布局、内联、符号等方面可能略有差异，理论上存在**厂商 .ko 加载失败或异常**的风险。 |
| **Vermagic** | 内核模块会校验 vermagic（内核版本+配置指纹）。不同编译器可能改变部分配置或版本字符串，导致设备上已有 vendor_dlkm 模块报 vermagic 不匹配。我们已关闭 `CONFIG_MODULE_SIG_PROTECT`，仅剩 vermagic 等兼容性风险。 |
| **能否刷入/启动** | **多数情况下可正常启动**：内核本身能编过、能打包、能 `fastboot boot`。是否影响使用取决于设备上厂商模块是否对 ABI/vermagic 敏感。vivo X100 Pro 的 vendor_dlkm 较多，建议**务必先 `fastboot boot` 临时引导测试**，再决定是否 `fastboot flash boot`。 |
| **若出现模块加载失败** | 可考虑改用 AOSP clang 本地构建（见下文「可选方案」），或使用 repo sync 在 CI/本地拉取完整内核树（含 prebuilts）再编。 |

**结论**：用 LLVM 18（apt.llvm.org）的构建**可以刷入并尝试使用**，但兼容性不如 AOSP clang 有保障；先做临时启动测试，再决定是否长期使用或改用 AOSP 工具链。

---

## 2. 可选方案：如何获得 AOSP Clang 再编译

若希望与官方 GKI 工具链一致，可采用以下方式之一：

- **本地 / 能访问镜像时**  
  - 使用 **repo 拉取 AOSP 内核 manifest**（含 prebuilts），再用该树中的 clang 编译。  
  - 参考：[WSL_BUILD.md](WSL_BUILD.md) 中的「使用清华镜像拉取」、[KERNEL_RESTORE_LOG.md](../../KERNEL_RESTORE_LOG.md) 中「AOSP kernel repo 拉取尝试」与 `scripts/aosp_kernel_sync_and_build.sh`。  
  - 拉取后 prebuilts 位于 `prebuilts/clang/host/linux-x86/clang-r487747c`，供 `build_wsl_standalone.sh` 或官方 `build.sh` 使用。

- **仅需 clang、不拉完整内核时**  
  - 从能访问的 AOSP 镜像或本机已有 AOSP 树中，复制 `prebuilts/clang/host/linux-x86/clang-r487747c` 到本仓库上一级或 `PREBUILTS_ROOT` 指定目录，然后按 [WSL_BUILD.md](WSL_BUILD.md) 使用 `build_wsl_standalone.sh`（不设 `USE_SYSTEM_CLANG=1`）。

- **CI 中不推荐**  
  - 在 GitHub Actions 中下载 AOSP 单目录归档当前不可用（子目录 URL 返回 400）；整仓归档体积过大且耗时长，故 CI 使用 **apt.llvm.org 的 LLVM 18**（固定版本，与 mcxiaochenn 用 clang-19 思路一致）。

---

## 3. 参考：其他内核 / CI 做法（思路可借鉴）

以下项目与设备/内核类型不同，但构建与工具链思路可参考：

| 来源 | 说明 | 与本仓库关系 |
|------|------|--------------|
| [利用 GitHub Action 编译安卓内核驱动](https://blog.p0.ee/2024/11/10/%E5%AE%89%E5%8D%93/%E5%88%A9%E7%94%A8github-Action%E7%BC%96%E8%AF%91%E5%AE%89%E5%8D%93%E5%86%85%E6%A0%B8%E9%A9%B1%E5%8A%A8/) | 使用 **repo init/sync** 拉取完整 Android 内核源码（如 `common-android12-5.10`），在 CI 中直接 `build/build.sh`；prebuilts 随 repo 一并拉取，无需单独下载 clang。 | 思路：若网络允许，可在 CI 或本地用 **repo + 镜像** 拉取 kernel manifest，用自带的 AOSP clang 编译。本仓库曾因网络问题 repo 失败，故当前 CI 不采用此方式。 |
| [mcxiaochenn/Action_OKI_KernelSU_SUSFS](https://github.com/mcxiaochenn/Action_OKI_KernelSU_SUSFS) | 一加/OPPO 设备，用 **apt 安装 LLVM 19**（`apt.llvm.org` 的 `clang-19`、`lld-19`），再配合 OnePlus 的 kernel manifest 与 Bazel 构建。设备与 vivo 不通用。 | **本仓库已采用其做法**：CI 中从 apt.llvm.org 安装 **LLVM 18**（clang-18、lld-18）固定工具链编译 AOSP GKI 源码树，不再使用 runner 默认 clang。 |
| LineageOS / 类原生内核 | 多为设备维度的内核树（如 MT6781、MT6877 等），MT6989 的 LineageOS 内核树未在公开检索中看到；GKI 构建通常仍依赖 AOSP/ACK 的 build 与 prebuilts。 | 本仓库为 GKI 6.1 + vivo 设备，与 LineageOS 设备树不是同一套源码，可作构建流程参考，不直接复用。 |
| 潘多拉内核（Pandora kernel） | 公开的 “pandora-kernel” 多为 OpenPandora 掌机内核，**非 Android GKI**，与本仓库用途不同。 | 不适用。 |

---

## 4. 建议流程小结

1. **当前 CI 产物**：用 **LLVM 18**（apt.llvm.org）编译，可直接用于 **`fastboot boot` 临时启动测试**。  
2. **若临时启动正常、模块无报错**：可继续使用该构建，或按需在本地用 AOSP clang 再编一份做对比。  
3. **若出现厂商模块加载失败、vermagic 报错等**：在本地或能访问镜像的环境用 **repo sync 拉取内核树（含 prebuilts）**，用 AOSP clang 重新编译后再测试。  
4. **文档与脚本**：  
   - 本地构建与镜像拉取：[WSL_BUILD.md](WSL_BUILD.md)  
   - CI 使用与产物：[GITHUB_ACTIONS_BUILD.md](GITHUB_ACTIONS_BUILD.md)  
   - 整体还原与决策记录：[KERNEL_RESTORE_LOG.md](../../KERNEL_RESTORE_LOG.md)
