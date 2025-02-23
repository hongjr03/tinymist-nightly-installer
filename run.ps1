#!powershell

# Validate arguments
if (($args.Count -gt 0) -and ($args[0] -ne "--stable") -and ($args[0] -ne "--nightly")) {
    Write-Host "Usage: run.ps1 [--stable|--nightly]"
    Write-Host "Defaulting to nightly build without arguments."
    Write-Host ""
    Write-Host " --stable: Install the latest stable release"
    Write-Host " --nightly: Install the latest nightly build"
    Write-Host ""
    Write-Host "Example: .\run.ps1 --stable"
    exit 1
}

# Set build type; default to nightly if no argument is given
$build = if ($args.Count -eq 0) { "--nightly" } else { $args[0] }

# Change code page to 65001 (UTF-8)
chcp 65001 > $null

$DOWNLOAD_DIR = $env:TEMP
$uname = "win32"

# Determine CPU architecture using systeminfo
$system_info = systeminfo | Select-String "System Type" | ForEach-Object { $_.Line }
$uname_m = if ($system_info -match "x64") {
    "x64"
} elseif ($system_info -match "ARM64") {
    "arm64"
} else {
    Write-Host "Unsupported system type: $system_info"
    exit 1
}

$FILENAME = "tinymist-$uname-$uname_m.vsix"

if ($build -eq "--stable") {
    Write-Host "Checking for latest stable release..."
    $DOWNLOAD_URL = "https://github.com/Myriad-Dreamin/tinymist/releases/latest/download/$FILENAME"
    $INFO_URL     = "https://api.github.com/repos/myriad-dreamin/tinymist/releases/latest"
    try {
        $stableJson = Invoke-RestMethod -Uri $INFO_URL -UseBasicParsing
    } catch {
        Write-Host "Failed to fetch stable release info."
        exit 1
    }
    $DISPLAY_TITLE = $stableJson.tag_name
    $UPDATED_AT    = $stableJson.published_at
    $URL           = $stableJson.html_url
    # For stable release, no zip file wrapping
    $ZIPFILE = Join-Path $DOWNLOAD_DIR $FILENAME
} else {
    Write-Host "Checking for latest nightly build..."
    $DOWNLOAD_URL = "https://nightly.link/Myriad-Dreamin/tinymist/workflows/release-vscode/main/$FILENAME.zip"
    $INFO_URL     = "https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
    try {
        $nightlyJson = Invoke-RestMethod -Uri $INFO_URL -UseBasicParsing
    } catch {
        Write-Host "Failed to fetch nightly build info."
        exit 1
    }
    $DISPLAY_TITLE = $nightlyJson.workflow_runs[0].display_title
    $UPDATED_AT    = $nightlyJson.workflow_runs[0].updated_at
    $URL           = $nightlyJson.workflow_runs[0].html_url
    $ZIPFILE       = Join-Path $DOWNLOAD_DIR "$FILENAME.zip"
}

Write-Host $DISPLAY_TITLE
Write-Host "Build Time (UTC): $UPDATED_AT"
Write-Host "For more information, visit: $URL"
Write-Host ""
Write-Host "Downloading $FILENAME from $DOWNLOAD_URL"
Write-Host ""

try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ZIPFILE -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "File download failed: $DOWNLOAD_URL"
    exit 1
}

if ($build -ne "--stable") {
    try {
        Expand-Archive -Path $ZIPFILE -DestinationPath $DOWNLOAD_DIR -Force
    } catch {
        Write-Host "Failed to unzip file: $ZIPFILE"
        exit 1
    }
    Write-Host "File downloaded and unzipped to $(Join-Path $DOWNLOAD_DIR $FILENAME)"
}

# Install the VS Code extension
$extensionPath = Join-Path $DOWNLOAD_DIR $FILENAME
$installProcess = Start-Process code -ArgumentList "--install-extension", $extensionPath -Wait -PassThru

if ($installProcess.ExitCode -eq 0) {
    Write-Host "VS Code extension installed successfully: $FILENAME"
    Write-Host "Please reload VS Code to activate the extension"
} else {
    Write-Host "VS Code extension installation failed"
}

Remove-Item -Path $ZIPFILE, $extensionPath -Force -ErrorAction SilentlyContinue
