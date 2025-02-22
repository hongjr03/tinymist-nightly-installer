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

## Notes

Please ensure that your system has the [VSCode CLI](https://code.visualstudio.com/docs/editor/command-line) installed.
