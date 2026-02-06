# RE_VKI 仓库推送与 Action 配置日志

## 仓库

- **URL**: https://github.com/XingChenRS/RE_VKI
- **分支**: `main`

## 2026-02-07 推送记录

### 1. 整理内容

- **根目录 `.gitignore`**：排除 `out/`、`device_extract/`（整目录，避免镜像/二进制入仓）、`AOSP_KERNEL_BUILD_LOG.txt`、常见构建产物与编辑器临时文件。
- **根目录 `README.md`**：说明 RE_VKI 用途、GitHub Actions 构建、本地 WSL 构建、刷机注意及日志文档链接。

### 2. Git 操作

- 在内核源码根目录（`android_16.0_kernel_MT6989`）执行：
  - `git init`
  - `git add .`（已忽略 `device_extract/` 与 `out/`）
  - `git commit -m "vivo GKI kernel: vivo_restore fragment + GitHub Actions build"`
  - `git branch -M main`
  - `git remote add origin https://github.com/XingChenRS/RE_VKI.git`
- **首次推送失败**：GitHub 报错 `GH007: Your push would publish a private email address`（邮箱隐私保护）。
- **处理**：在本仓库内设置 `user.email=XingChenRS@users.noreply.github.com`、`user.name=XingChenRS`，执行 `git commit --amend --reset-author --no-edit` 后再次推送。
- **推送结果**：`git push -u origin main` 成功，`main` 已跟踪 `origin/main`。

### 3. GitHub Actions

- **Workflow 文件**：`.github/workflows/build-kernel.yml`（已随提交推送）。
- **触发**：
  - **push** 到 `main` 或 `master` 会**自动**触发一次 “Build GKI Kernel”。
  - **手动**：Actions → Build GKI Kernel → Run workflow（可勾选 KernelSU、系统 clang 回退）。
- **本次**：推送到 `main` 后应已自动触发一次运行。请在 [Actions 页](https://github.com/XingChenRS/RE_VKI/actions) 查看运行状态与日志；若未自动运行，可手动 “Run workflow”。
- **产物**：单次 Run 的 **Artifacts** 中可下载 `kernel-<run>-<sha>`（含 Image、Image.gz、Image.lz4）。

### 4. 后续操作建议

1. 打开 https://github.com/XingChenRS/RE_VKI/actions 确认是否有 “Build GKI Kernel” 运行及是否成功。
2. 若需创建 Release：仓库 **Settings → Actions → General** 中，将 **Workflow permissions** 设为 **Read and write permissions**。
3. 打包与刷机：从 Artifacts 取镜像后，按 `Documentation/android/vivo_mt6989_boot_repack.txt` 操作；**务必先用 `fastboot boot` 测试。**

---

以上已同步记入 `KERNEL_RESTORE_LOG.md` 第 8 节（GitHub Actions）及本文件。
