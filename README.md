# tinymist-(nightly)-installer

English | [简体中文](README.zh-CN.md)

This repository is used to install the nightly version of tinymist, downloading the latest build from [tinymist::ci](https://github.com/Myriad-Dreamin/tinymist/actions/workflows/release-vscode.yml). It can also be used to install the latest stable release.

## Installation

Copy the corresponding command to the terminal and run it.

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

### Advanced Usage

For advanced usage scenarios, it's recommended to download the script first and then execute it locally:

```bash
# Download the script
curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh -o tinymist-installer.sh
chmod +x tinymist-installer.sh

# Execute with various options
./tinymist-installer.sh [extension|binary] [--stable|--nightly|--run <run_id>|--pr <pr_number>]
```

Example usage:

```bash
# Install specific artifact from run ID
./tinymist-installer.sh binary --run 13916708000

# Install specific artifact from PR number
./tinymist-installer.sh extension --pr 1500
```

Alternatively, you can use the direct pipe method, though it's less convenient for multiple uses:

```bash
# Install specific artifact from run ID
curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh | bash -s -- [extension|binary] --run <run_id>

# Install specific artifact from PR number
curl -sSL https://github.com/hongjr03/tinymist-nightly-installer/releases/latest/download/run.sh | bash -s -- [extension|binary] --pr <pr_number>
```

## Features

- Automatic detection of system architecture
- Installation of both VS Code extension and binary
- Support for both stable releases and nightly builds
- Installation from specific GitHub Actions run IDs
- Installation from Pull Request builds
- Efficient handling of temporary files
- Proper error handling and logging

## Notes

- Please ensure that your system has the [VSCode CLI](https://code.visualstudio.com/docs/editor/command-line) installed.
- The script requires `curl`, `jq`, and `unzip` to function properly.
- All downloaded and temporary files are properly managed and cleaned up after installation.
