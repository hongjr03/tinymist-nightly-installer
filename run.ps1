#!powershell

# Change code page to 65001 (UTF-8)
chcp 65001 > $null

$DOWNLOAD_DIR = $env:TEMP
$uname = "win32"

# Determine CPU architecture using systeminfo
$system_info = systeminfo | Select-String "System Type" | ForEach-Object { $_.Line }
$uname_m = if ($system_info -match "x64") {
    "x64"
}
elseif ($system_info -match "ARM64") {
    "arm64"
}
else {
    Write-Host "Unsupported system type: $system_info"
    exit 1
}
$FILENAME = "tinymist-$uname-$uname_m.vsix"

function Get-NightlyLink {
    <#
        .SYNOPSIS
            Get the download link for the nightly build.
        .DESCRIPTION
            This function generates the download link for the nightly build based on the run ID and the filename.
        .PARAMETER run_id
            The ID of the nightly build run.
        .PARAMETER filename
            The name of the file to download.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Int64]$run_id,
        [Parameter(Mandatory = $true)]
        [System.String]$filename
    )

    return "https://nightly.link/Myriad-Dreamin/tinymist/actions/runs/$run_id/$filename.zip"
}

function Get-RunInfo {
    <#
        .SYNOPSIS
            Get information about the latest nightly build run.
        .DESCRIPTION
            This function retrieves information about the latest nightly build run, including the run ID, URLs, Used Commit and so on.
        .PARAMETER run
            The GitHub run object.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$run
    )

    $run_id = $run.id
    $head_commit = $run.head_commit.id
    $extension_filename = "tinymist-$uname-$uname_m.vsix"
    $binary_filename = "tinymist-$uname-$uname_m"


    # Convert UTC time to local time
    $updated_at = $run.updated_at
    try {
        $utcDateTime = [datetime]::ParseExact($updated_at, "yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)
        $localDateTime = $utcDateTime.ToLocalTime()
        $updated_at = $localDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        # Keep the original format if conversion fails
    }

    return @{
        run_id                 = $run_id
        url                    = $run.html_url
        display_title          = $run.display_title
        updated_at             = $updated_at
        head_commit            = $head_commit
        extension_filename     = $extension_filename
        extension_download_url = Get-NightlyLink $run_id $extension_filename
        binary_filename        = $binary_filename
        binary_download_url    = Get-NightlyLink $run_id $binary_filename
    }
}

function Read-RepoPackageJson {
    <#
        .SYNOPSIS
            Read the package.json file from the extension repository.
        .PARAMETER runInfo
            The run information object.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$runInfo
    )

    $PackageJsonUrl = "https://raw.githubusercontent.com/Myriad-Dreamin/tinymist/$($runInfo.head_commit)/editors/vscode/package.json"
    try {
        $PackageJson = Invoke-RestMethod -Uri $PackageJsonUrl -UseBasicParsing
    }
    catch {
        Write-Host "Failed to fetch package.json from $PackageJsonUrl."
        exit 1
    }

    return $PackageJson
}

function Get-ArtifactFromRun {
    <#
        .SYNOPSIS
            Gets the VS Code extension from the specified URL.
        .PARAMETER runInfo
            The run information object.
        .PARAMETER fileName
            The name of the file to download.
        .PARAMETER downloadUrl
            The URL to download the file from.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$runInfo,
        [Parameter(Mandatory = $true)]
        [System.String]$fileName,
        [Parameter(Mandatory = $true)]
        [System.String]$downloadUrl
    )

    $FilePath = Join-Path $DOWNLOAD_DIR $fileName
    $FileZipPath = "$FilePath.zip"

    Write-Host "Title: $($runInfo.display_title)"
    Write-Host "Build Time: $($runInfo.updated_at)"
    Write-Host "For more information, visit: $($runInfo.url)"
    if ($null -ne $runInfo.prUrl) {
        Write-Host "Related PR: $($runInfo.prUrl)"
    }
    Write-Host ""
    Write-Host "Downloading $fileName from $downloadUrl..."
    Write-Host ""

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $FileZipPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "File download failed: $downloadUrl"
        exit 1
    }

    try {
        if (Test-Path $FilePath) {
            Remove-Item -Path $FilePath -Force
        }

        # Expand-Archive -Path $FileZipPath -DestinationPath $FilePath -Force

        Add-Type -Assembly System.IO.Compression.FileSystem

        #extract list entries for dir myzipdir/c/ into myzipdir.zip
        $Zip = [IO.Compression.ZipFile]::OpenRead($FileZipPath)
        $Entries = $Zip.Entries | Where-Object { $_.FullName -like $fileName } 

        #extraction
        $Entries | ForEach-Object { [IO.Compression.ZipFileExtensions]::ExtractToFile( $_, $FilePath ) }

        #free object
        $Zip.Dispose()

        Remove-Item -Path $FileZipPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "Failed to unzip file: $FilePath"
        exit 1
    }

    Write-Host "Extension file is ready on $FilePath"
    return $FilePath
}

function Get-ExtensionFileFromRunInfo {
    <#
        .SYNOPSIS
            Gets the VS Code extension from the specified URL.
        .PARAMETER runInfo
            The run information object.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$runInfo
    )

    return Get-ArtifactFromRun $runInfo $runInfo.extension_filename $runInfo.extension_download_url
}

function Get-ExtensionFileFromRelease {
    <#
        .SYNOPSIS
            Gets the VS Code extension from the latest stable release.
        .DESCRIPTION
            Downloads the extension file from the GitHub releases page.
        .PARAMETER fileName
            Optional. The specific filename to download. Defaults to the platform-specific filename.
    #>

    param (
        [Parameter(Mandatory = $false)]
        [System.String]$fileName = $FILENAME
    )

    $RELEASE_URL = "https://api.github.com/repos/myriad-dreamin/tinymist/releases/latest"
    Write-Host "Checking for latest stable release..."
    Write-Host ""
    
    try {
        $releaseInfo = Invoke-RestMethod -Uri $RELEASE_URL -UseBasicParsing
    }
    catch {
        Write-Host "Failed to fetch stable release info."
        exit 1
    }
    
    $tag = $releaseInfo.tag_name
    $updated_at = $releaseInfo.published_at
    $url = $releaseInfo.html_url
    $download_url = ""
    
    # Convert UTC time to local time
    try {
        $utcDateTime = [datetime]::ParseExact($updated_at, "yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)
        $localDateTime = $utcDateTime.ToLocalTime()
        $updated_at = $localDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        # Keep the original format if conversion fails
    }
    
    # Find asset with matching filename
    foreach ($asset in $releaseInfo.assets) {
        if ($asset.name -eq $fileName) {
            $download_url = $asset.browser_download_url
            break
        }
    }
    
    if (-not $download_url) {
        Write-Host "Could not find $fileName in release assets."
        exit 1
    }
    
    $filePath = Join-Path $DOWNLOAD_DIR $fileName
    
    Write-Host "Title: $tag"
    Write-Host "Release Date: $updated_at"
    Write-Host "For more information, visit: $url"
    Write-Host ""
    Write-Host "Downloading $fileName from $download_url..."
    Write-Host ""
    
    try {
        Invoke-WebRequest -Uri $download_url -OutFile $filePath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "File download failed: $download_url"
        exit 1
    }
    
    Write-Host "Extension file is ready on $filePath"
    return $filePath
}

function Test-VscodeRequirement {
    <#
        .SYNOPSIS
            Examines the VS Code version and checks compatibility with the extension.
        .PARAMETER vscodeRequire
            The required version of VS Code extracted from the package.json file.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.String]$vscodeRequire
    )
    
    Write-Host ""
    Write-Host "VS Code version required: $vscodeRequire"
    
    # Check if the extension is compatible with the current version of VS Code
    try {
        $InstalledVersion = (& code --version)[0]
        Write-Host "VS Code version installed: $InstalledVersion"
        Write-Host ""
        
        # Extract minimum required version (remove ^, ~, >, =, < and any other prefixes)
        $MinVersion = $vscodeRequire -replace '[^\d\.]'
        
        # Compare versions
        if ([version]$InstalledVersion -lt [version]$MinVersion) {
            Write-Host "VS Code version mismatch, please update to at least $MinVersion"
            exit 1
        }
    }
    catch {
        Write-Host "Failed to check VS Code version compatibility."
        Write-Host "Make sure VS Code is installed and accessible in PATH."
        exit 1
    }
}

function Install-Extension {
    <#
        .SYNOPSIS
            Installs the VS Code extension.
        .PARAMETER extensionPath
            The path to the extension file.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.String]$extensionPath
    )

    $FileName = Split-Path $extensionPath -Leaf

    # # Install the VS Code extension
    $installProcess = Start-Process code -ArgumentList "--install-extension", $extensionPath -Wait -PassThru

    if ($installProcess.ExitCode -eq 0) {
        Write-Host "VS Code extension installed successfully: $FileName"
        Write-Host "Please reload VS Code to activate the extension"
    }
    else {
        Write-Host "VS Code extension installation failed"
    }
}

function Install-Binary {
    <#
        .SYNOPSIS
            Installs the binary file.
        .PARAMETER binaryPath
            The path to the binary file.
        .PARAMETER fileName
            The name of the binary file.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.String]$binaryPath,
        [Parameter(Mandatory = $false)]
        [System.String]$fileName = $( Split-Path $binaryPath -Leaf )
    )
    

    $LocalBinDir = "$env:USERPROFILE\.local\bin"
    $LocalBinPath = Join-Path $LocalBinDir $fileName

    if (-not (Test-Path $LocalBinDir)) {
        New-Item -Path $LocalBinDir -ItemType Directory -Force | Out-Null
    }

    if (Test-Path $LocalBinPath) {
        Remove-Item -Path $LocalBinPath -Force
    }

    Copy-Item -Path $binaryPath -Destination $LocalBinPath -Force

    try {
        $BinVersion = (& $LocalBinPath --version)
    }
    catch {
        Write-Host "Binary file installation is not valid: $LocalBinPath"
        exit 1
    }

    Write-Host "Binary file installed successfully: $LocalBinPath"
    Write-Output $BinVersion
    Write-Host "Please make sure $LocalBinDir is in your PATH"
}

function Get-LatestNightlyRunInfo {
    <#
        .SYNOPSIS
            Gets run information about the latest nightly build run.
    #>

    $INFO_URL = "https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
    try {
        $nightlyJson = Invoke-RestMethod -Uri $INFO_URL -UseBasicParsing
    }
    catch {
        Write-Host "Failed to fetch nightly build info."
        exit 1
    }
    
    return Get-RunInfo $nightlyJson.workflow_runs[0]
}

function Install-ExtensionFromRunInfo {
    <#
        .SYNOPSIS
            Installs the latest nightly build of the VS Code extension.
        .PARAMETER runInfo
            The run information object.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$runInfo
    )

    $PackageJson = Read-RepoPackageJson $runInfo
    Test-VscodeRequirement $PackageJson.engines.vscode

    $ExtensionPath = Get-ArtifactFromRun $runInfo $runInfo.extension_filename $runInfo.extension_download_url
    Install-Extension $ExtensionPath
    Remove-Item -Path $ExtensionPath -Force -ErrorAction SilentlyContinue
}

function Install-BinaryFromRunInfo {
    <#
        .SYNOPSIS
            Installs the latest nightly build of the VS Code extension.
        .PARAMETER runInfo
            The run information object.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$runInfo
    )

    $BinaryPath = Get-ArtifactFromRun $runInfo "$($runInfo.binary_filename).exe" $runInfo.binary_download_url
    Install-Binary $BinaryPath "tinymist.exe"
    Remove-Item -Path $BinaryPath -Force -ErrorAction SilentlyContinue
}

function Install-ArtifactFromRunInfo {
    <#
        .SYNOPSIS
            Installs the latest nightly build of the VS Code extension.
        .PARAMETER runInfo
            The run information object.
        .PARAMETER artifactName
            The name of the artifact to install. Either "extension" or "binary".
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Object]$runInfo,
        [Parameter(Mandatory = $true)]
        [System.String]$artifactName
    )

    if ($artifactName -eq "extension") {
        Install-ExtensionFromRunInfo $runInfo
    }
    elseif ($artifactName -eq "binary") {
        Install-BinaryFromRunInfo $runInfo
    }
    else {
        Write-Host "Invalid artifact name: $artifactName"
        exit 1
    }
}

function Install-LatestNightlyArtifact {
    <#
        .SYNOPSIS
            Installs the latest nightly build of the VS Code extension.
        .PARAMETER artifactName
            The name of the artifact to install. Either "extension" or "binary".
    #>

    $RunInfo = Get-LatestNightlyRunInfo
    Install-ArtifactFromRunInfo $RunInfo $artifactName
}

function Install-LatestStableArtifact {
    <#
        .SYNOPSIS
            Installs the latest nightly build of the VS Code extension.
        .PARAMETER artifactName
            The name of the artifact to install. Either "extension" or "binary".
    #>
}

function Install-ArtifactByRunId {
    <#
        .SYNOPSIS
            Installs the VS Code extension from a specific nightly build run.
        .PARAMETER runId
            The ID of the nightly build run.
        .PARAMETER artifactName
            The name of the artifact to install. Either "extension" or "binary".
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.String]$runId,
        [Parameter(Mandatory = $true)]
        [System.String]$artifactName
    )
    
    $InfoUrl = "https://api.github.com/repos/myriad-dreamin/tinymist/actions/runs/$runId"

    try {
        $RunJson = Invoke-RestMethod -Uri $InfoUrl -UseBasicParsing
    }
    catch {
        Write-Host "Failed to fetch release info."
        exit 1
    }

    $RunInfo = Get-RunInfo $RunJson
    Install-ArtifactFromRunInfo $RunInfo $artifactName
}

function Install-ArtifactByPrNumber {
    <#
        .SYNOPSIS
            Installs the VS Code extension from a specific pull request.
        .PARAMETER prNumber
            The ID of the nightly build run.
        .PARAMETER artifactName
            The name of the artifact to install. Either "extension" or "binary".
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.String]$prNumber,
        [Parameter(Mandatory = $true)]
        [System.String]$artifactName
    )
    
    $PrInfoUrl = "https://api.github.com/repos/myriad-dreamin/tinymist/pulls/$prNumber"

    try {
        $PrJson = Invoke-RestMethod -Uri $PrInfoUrl -UseBasicParsing
    }
    catch {
        Write-Host "Failed to fetch PR info."
        exit 1
    }

    $PrHeadSha = $PrJson.head.sha

    $ShaRunsUrl = "https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&head_sha=$PrHeadSha&status=success"

    try {
        $PrRunsJson = Invoke-RestMethod -Uri $ShaRunsUrl -UseBasicParsing
    }
    catch {
        Write-Host "Failed to fetch PR workflow runs info."
        exit 1
    }

    if ($PrRunsJson.total_count -eq 0) {
        Write-Host "No successful workflow runs found for PR $prNumber"
        exit 1
    }

    $RunInfo = Get-RunInfo $PrRunsJson.workflow_runs[0]
    $RunInfo.display_title = "PR #$prNumber $($PrJson.title) - $($RunInfo.display_title)"
    $RunInfo.prUrl = $PrJson.html_url
    Install-ArtifactFromRunInfo $RunInfo $artifactName
}

function Write-Help {
    Write-Host "Usage: run.ps1 [extension|binary] [--stable|--nightly|--run <run_id>|--pr <pr_number>]"
    Write-Host "Defaulting to nightly build without arguments."
    Write-Host ""
    Write-Host " --stable: Install the latest stable release"
    Write-Host " --nightly: Install the latest nightly build"
    Write-Host ""
    Write-Host "Example: .\run.ps1 --stable"
    Write-Host ""
    Write-Host "Example: .\run.ps1 --nightly"
    Write-Host ""
    Write-Host "Example: .\run.ps1 --run 13916708000"
    Write-Host ""
    Write-Host "Example: .\run.ps1 binary --run 13916708000"
    Write-Host ""
    Write-Host "Example: .\run.ps1 binary --pr 1500"
}

# Parse command line arguments
$ArtifactName = "extension"
$Build = "--nightly"
$RunId = $null
$PrNumber = $null

if ($args.Count -gt 0) {
    $ArtifactName = $args[0]
    if ($args.Count -gt 1) {
        $Build = $args[1]
        if ($args.Count -gt 2) {
            if ($Build -eq "--run") {
                $RunId = $args[2]
    
                if (-not [System.Int64]::TryParse($RunId, [ref]$null)) {
                    Write-Host "Invalid run ID: $RunId"
                    exit 1
                }
            }
            elseif ($Build -eq "--pr") {
                $PrNumber = $args[2]
    
                if (-not [System.Int64]::TryParse($PrNumber, [ref]$null)) {
                    Write-Host "Invalid pr Number: $PrNumber"
                    exit 1
                }
            }
            else {
                Write-Help
                exit 1
            }
        }
    }
}

if ($Build -eq "--stable") {
    Install-LatestStableArtifact $ArtifactName
}
elseif ($Build -eq "--nightly") {
    Install-LatestNightlyArtifact $ArtifactName
}
elseif ($null -ne $RunId) {
    Install-ArtifactByRunId $RunId $ArtifactName
}
elseif ($null -ne $PrNumber) {
    Install-ArtifactByPrNumber $PrNumber $ArtifactName
}
else {
    Write-Help
}
