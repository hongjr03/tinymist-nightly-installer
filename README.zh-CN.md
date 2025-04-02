# tinymist-(nightly)-installer

[English](README.md) | 简体中文

本仓库用于安装 nightly 版本的 tinymist，下载 [tinymist::ci](https://github.com/Myriad-Dreamin/tinymist/actions/workflows/release-vscode.yml) 构建的最新版本。也可以用来安装最新的 stable 发行版。

## 安装

复制对应的命令到终端中运行即可。

### Nightly

- Unix (Bash):

    ```bash
    curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh | bash
    ```

- Windows (PowerShell):

    ```powershell
    iwr https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.ps1 -UseBasicParsing | iex
    ```

### Stable

- Unix (Bash):

    ```bash
    curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh | bash -s -- --stable
    ```

- Windows (PowerShell):

    ```powershell
    iwr https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.ps1 -UseBasicParsing | iex -ArgumentList '--stable'
    ```

### 高级用法

对于高级用法场景，建议先下载脚本然后在本地执行：

```bash
# 下载脚本
curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh -o tinymist-installer.sh
chmod +x tinymist-installer.sh

# 使用各种选项执行
./tinymist-installer.sh [extension|binary] [--stable|--nightly|--run <run_id>|--pr <pr_number>]
```

使用示例：

```bash
# 从特定的 run ID 安装二进制文件
./tinymist-installer.sh binary --run 13916708000

# 从特定的 PR 号码安装扩展
./tinymist-installer.sh extension --pr 1500
```

或者，你也可以使用以下命令：

```bash
# 从特定的 run ID 安装
curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh | bash -s -- [extension|binary] --run <run_id>

# 从特定的 PR 号码安装
curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh | bash -s -- [extension|binary] --pr <pr_number>
```

## 功能特点

- 自动检测系统架构
- 支持安装 VS Code 扩展和二进制文件
- 支持稳定版和每日构建版本
- 支持从特定 GitHub Actions 运行 ID 安装
- 支持从 Pull Request 构建版本安装
- 高效处理临时文件
- 完善的错误处理和日志记录

## 注意事项

- 请确保你的系统中已经安装了 [VSCode CLI](https://code.visualstudio.com/docs/editor/command-line)。
- 脚本需要 `curl`、`jq` 和 `unzip` 才能正常运行。
- 所有下载和临时文件在安装后会被妥善管理和清理。
