# RE_VKI — vivo GKI 内核（可还原/自定义构建）

基于 Android Common Kernel 6.1（GKI），面向 **vivo X100 Pro（MT6989）** 的可构建内核树。在标准 `gki_defconfig` 上关闭 `CONFIG_MODULE_SIG_PROTECT`（`vivo_restore_gki.fragment`），便于与设备已有 vendor 模块兼容。

## 构建方式

**推荐：GitHub Actions 云端编译**

- 打开 [Actions](https://github.com/XingChenRS/RE_VKI/actions) → 选择 **Build GKI Kernel** → **Run workflow**。
- 可选集成 [KernelSU](https://kernelsu.org/)；AOSP clang 下载失败时会回退到系统 clang。
- 构建产物在对应 Run 的 **Artifacts** 中下载（Image / Image.gz / Image.lz4）。

详细步骤见 [Documentation/android/GITHUB_ACTIONS_BUILD.md](Documentation/android/GITHUB_ACTIONS_BUILD.md)。

## 本地构建（WSL）

见 [Documentation/android/WSL_BUILD.md](Documentation/android/WSL_BUILD.md)。需准备 AOSP clang（r487747c）或使用系统 clang（`USE_SYSTEM_CLANG=1`）。

## 刷机与测试

用 Artifacts 中的镜像按 [Documentation/android/vivo_mt6989_boot_repack.txt](Documentation/android/vivo_mt6989_boot_repack.txt) 重打包 boot。**务必先用 `fastboot boot` 临时启动测试，勿直接 `fastboot flash boot`。**

## 日志与说明

- [KERNEL_RESTORE_LOG.md](KERNEL_RESTORE_LOG.md) — 设备提取、配置与构建决策记录。
- [device_extract](device_extract/) — 本地设备提取数据与脚本（未纳入 git，仅本地保留）。

## License

与上游 Linux / Android 内核一致（GPL-2.0 等）。
