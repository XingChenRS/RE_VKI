# 使用 GitHub Actions 编译内核

本仓库已包含用 **GitHub Actions** 在云端编译 GKI 内核的 workflow，支持**可选集成 KernelSU**。无需本地拉取 AOSP、无需 WSL，把改好的源码推到 GitHub 即可在 Action 里编译出 `Image` / `Image.gz` / `Image.lz4`。

**工具链说明**：CI 中**不下载 AOSP Clang**（归档 URL 不可用），采用 [mcxiaochenn/Action_OKI_KernelSU_SUSFS](https://github.com/mcxiaochenn/Action_OKI_KernelSU_SUSFS) 的做法，从 **apt.llvm.org** 安装 **LLVM 18**（clang-18、lld-18）作为固定工具链编译。对刷机兼容性的影响及可选方案见 [SYSTEM_CLANG_IMPACT_AND_ALTERNATIVES.md](SYSTEM_CLANG_IMPACT_AND_ALTERNATIVES.md)。

## 1. 新建仓库并推送源码

1. 在 GitHub 新建一个**空仓库**（例如 `vivo-x100pro-gki`），不要勾选 README（避免首次 push 冲突）。
2. 在本机进入当前内核源码根目录（即包含 `arch/`、`build.config.*`、`.github/` 的目录），执行：

```bash
git init
git add .
git commit -m "vivo GKI kernel with vivo_restore fragment and GitHub Actions"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

若仓库已有内容，可先 `git pull --rebase` 再 `git push`。

## 2. 启用 Actions 并运行构建

1. 打开该仓库 → **Actions** 标签页，若提示启用 Workflows，选择 **I understand my workflows, go ahead and enable them**。
2. 左侧选择 **"Build GKI Kernel"**。
3. 运行方式二选一：
   - **手动运行**：点击 **Run workflow**，选择分支（如 `main`），可选：
     - **Integrate KernelSU**：勾选则会在构建前执行 KernelSU 的 `setup.sh`（推荐）。
   - **自动运行**：每次向 `main` / `master` 分支 push（或对这两个分支的 PR）都会自动触发一次构建。  
   （当前 CI 使用 apt.llvm.org 的 LLVM 18 编译，与 [Google android14-6.1 发布说明](https://source.android.com/docs/core/architecture/kernel/gki-android14-6_1-release-builds) 对应同一内核线，工具链为固定版本、非 AOSP prebuilts。）

## 3. 获取构建产物

- **Artifacts**：每次运行结束后，在该次 Run 页面下方 **Artifacts** 中下载 `kernel-<run>-<sha>`，解压可得：
  - `Image`
  - `Image.gz`
  - `Image.lz4`
- **Release**：仅在**手动运行** workflow 且分支为 `main` 或 `master` 时，会尝试创建一次 GitHub Release 并上传上述文件；若权限不足可忽略，只用 Artifacts 即可。

## 4. 打包与刷机

用下载到的 `Image.lz4`（或 `Image.gz`）按 `Documentation/android/vivo_mt6989_boot_repack.txt` 和 `device_extract/imgread` 中的 magiskboot 步骤重打包 boot 镜像。**务必先用 `fastboot boot` 临时启动测试，确认无误后再考虑 `fastboot flash boot`。**

## 5. 参考

- **KernelSU 集成**：[KernelSU - How to build](https://kernelsu.org/guide/how-to-build.html)（本 workflow 通过 `setup.sh` 自动打补丁）。
- **Chopin 风格多仓库构建**：[ChopinKernels/kernel-builder-chopin](https://github.com/ChopinKernels/kernel-builder-chopin)（从配置文件拉取多个内核仓库并编译，可选 KernelSU）。
- **仅构建内核模块**：[feicong/android-kernel-build-action](https://github.com/feicong/android-kernel-build-action)（针对 GKI 模块 ko，非完整内核镜像）。
- **repo sync 在 CI 中拉完整内核+prebuilts**：[利用 GitHub Action 编译安卓内核驱动](https://blog.p0.ee/2024/11/10/%E5%AE%89%E5%8D%93/%E5%88%A9%E7%94%A8github-Action%E7%BC%96%E8%AF%91%E5%AE%89%E5%8D%93%E5%86%85%E6%A0%B8%E9%A9%B1%E5%8A%A8/)（思路：CI 里 repo init/sync 后用 build.sh，prebuilts 随树拉取）。
- **一加 KernelSU 多分支 CI（使用 apt LLVM 19）**：[mcxiaochenn/Action_OKI_KernelSU_SUSFS](https://github.com/mcxiaochenn/Action_OKI_KernelSU_SUSFS)（设备为 OPPO/一加，vivo 不兼容；可参考其用系统/LLVM 官方 clang 的做法）。

## 6. 常见问题

- **为何不用 AOSP clang**：googlesource 子目录归档返回 400，整仓过大；CI 改用 **apt.llvm.org 的 LLVM 18**（参考 mcxiaochenn 的 apt 安装 Clang 方式）。对兼容性影响及本地用 AOSP clang 的替代方案见 [SYSTEM_CLANG_IMPACT_AND_ALTERNATIVES.md](SYSTEM_CLANG_IMPACT_AND_ALTERNATIVES.md)。
- **构建超时**：默认 120 分钟；若仍不够，可在 `.github/workflows/build-kernel.yml` 中增大 `timeout-minutes`。
- **Release 403**：在仓库 **Settings → Actions → General** 中，将 **Workflow permissions** 设为 **Read and write permissions**，保存后重新运行 workflow。
