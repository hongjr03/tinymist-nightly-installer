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

## 注意事项

请确保你的系统中已经安装了 [VSCode CLI](https://code.visualstudio.com/docs/editor/command-line)，并配置了科学上网环境。
