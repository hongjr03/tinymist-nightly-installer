# tinymist-nightly-installer

本仓库用于安装 nightly 版本的 tinymist，下载 [tinymist::ci](https://github.com/Myriad-Dreamin/tinymist/actions/workflows/release-vscode.yml) 构建的最新版本。

## 快速开始

PowerShell 脚本仅支持 Windows 系统。

### Bash 脚本

复制并在命令行中运行：

```bash
wget https://github.com/hongjr03/tinymist-nightly-installer/raw/refs/heads/main/run.sh -O - | bash
```

### PowerShell 脚本

复制并在 PowerShell 中运行：

```powershell
iwr https://github.com/hongjr03/tinymist-nightly-installer/raw/refs/heads/main/run.ps1 -UseBasicParsing | iex
```

## 注意事项

请确保你的系统中已经安装了 `wget`、`unzip` 和 [VSCode CLI](https://code.visualstudio.com/docs/editor/command-line)，并配置了科学上网环境。
