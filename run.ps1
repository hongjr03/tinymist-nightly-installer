#!powershell

$DOWNLOAD_DIR = $env:TEMP

$uname = "win32"
# "System Type" or "系统类型"
$system_info = systeminfo | Select-String "System Type" | ForEach-Object { $_.Line }

$uname_m = if ($system_info -match "x64") {
    "x64"
} elseif ($system_info -match "ARM64") {
    "arm64"
} else {
    Write-Host "不支持的系统架构"
    [Environment]::Exit(1)
}

$FILENAME = "tinymist-$uname-$uname_m.vsix"
$ZIPFILE = Join-Path $DOWNLOAD_DIR "$FILENAME.zip"

$DOWNLOAD_URL = "https://nightly.link/Myriad-Dreamin/tinymist/workflows/release-vscode/main/$FILENAME.zip"
$NIGHTLY_URL = "https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
$nightlyJson = Invoke-RestMethod -Uri $NIGHTLY_URL -UseBasicParsing
$DISPLAY_TITLE = $nightlyJson.workflow_runs[0].display_title
$UPDATED_AT = $nightlyJson.workflow_runs[0].updated_at


Write-Host "Latest Build: $DISPLAY_TITLE"
Write-Host "Build Time (UTC): $UPDATED_AT"

try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ZIPFILE -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "File download failed: $DOWNLOAD_URL"
    [Environment]::Exit(1)
}

try {
    Expand-Archive -Path $ZIPFILE -DestinationPath $DOWNLOAD_DIR -Force
} catch {
    Write-Host "Failed to unzip file: $ZIPFILE"
    [Environment]::Exit(1)
}

Write-Host "File downloaded and unzipped to $(Join-Path $DOWNLOAD_DIR $FILENAME)"

$extensionPath = Join-Path $DOWNLOAD_DIR $FILENAME
$installProcess = Start-Process code -ArgumentList "--install-extension", $extensionPath -Wait -PassThru

if ($installProcess.ExitCode -eq 0) {
    Write-Host "VS Code extension installed successfully: $FILENAME"
    Write-Host "Please reload VS Code to activate the extension"
} else {
    Write-Host "VS Code extension installation failed"
}

Remove-Item -Path $ZIPFILE, $extensionPath -Force -ErrorAction SilentlyContinue