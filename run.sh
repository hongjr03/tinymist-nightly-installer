#!/bin/bash

# tinymist installer script
# This script installs the tinymist VS Code extension or binary
# Supports installation from latest stable, nightly builds, specific run IDs or PRs

# Define constants and variables
UNAME=$(uname | tr '[:upper:]' '[:lower:]')
UNAME_M=$(uname -m | tr '[:upper:]' '[:lower:]')
FILENAME="tinymist-$UNAME-$UNAME_M.vsix"
BINARY_FILENAME="tinymist-$UNAME-$UNAME_M"
NIGHTLY_URL="https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
RELEASE_URL="https://api.github.com/repos/myriad-dreamin/tinymist/releases/latest"
EXTENSION_PACKAGE_JSON_URL="https://raw.githubusercontent.com/Myriad-Dreamin/tinymist/refs/heads/main/editors/vscode/package.json"

# Helper function: Output log messages to stderr
log() {
  echo "$@" >&2
}

# Helper function: Output error messages to stderr
error() {
  echo "Error: $@" >&2
}

# Helper function: Output warning messages to stderr
warn() {
  echo "Warning: $@" >&2
}

# Helper function: Safely query with curl
safe_curl() {
  local url="$1"
  local output="$2"
  curl -s "$url" > "$output"
}

# Helper function: Safely download with curl (with redirect following)
safe_download() {
  local url="$1"
  local output="$2"
  curl -sL -o "$output" "$url"
}

print_system_info() {
  # Print system information
  log "System detected: $UNAME-$UNAME_M"
  log "Will download: $FILENAME"
  log ""
}

# Function definitions

# Print help information
print_help() {
  log "Usage: $0 [extension|binary] [--stable|--nightly|--run <run_id>|--pr <pr_number>]"
  log "Defaulting to nightly build without arguments."
  log ""
  log " --stable: Install the latest stable release"
  log " --nightly: Install the latest nightly build"
  log " --run: Install from a specific GitHub Actions run ID"
  log " --pr: Install from a specific Pull Request number"
  log ""
  log "Example: $0 --stable"
  log "Example: $0 --nightly"
  log "Example: $0 --run 13916708000"
  log "Example: $0 binary --run 13916708000"
  log "Example: $0 binary --pr 1500"
  log ""
}

# Get nightly link
get_nightly_link() {
  local run_id="$1"
  local filename="$2"
  
  echo "https://nightly.link/Myriad-Dreamin/tinymist/actions/runs/$run_id/$filename.zip"
}

# Get run information
get_run_info() {
  local run_file="$1"
  
  # Check if file exists
  if [ ! -f "$run_file" ] || [ ! -s "$run_file" ]; then
    error "Invalid run data file"
    exit 1
  fi
  
  # Check if input file contains valid JSON
  if ! jq empty < "$run_file" 2>/dev/null; then
    error "Invalid JSON run data"
    log "Run data: $(head -c 100 "$run_file")..."
    exit 1
  fi
  
  # Use jq to extract fields from file
  local run_id=$(jq -r '.id // empty' < "$run_file")
  local head_commit=$(jq -r '.head_sha // empty' < "$run_file")
  local display_title=$(jq -r '.display_title // empty' < "$run_file")
  local updated_at=$(jq -r '.updated_at // empty' < "$run_file")
  local url=$(jq -r '.html_url // empty' < "$run_file")
  
  # Print debug information
  log "Parsed run ID: $run_id"
  log "Parsed commit: $head_commit"
  
  # Check if necessary fields exist
  if [ -z "$run_id" ] || [ -z "$url" ]; then
    error "Could not obtain necessary run information from response"
    log "Run ID: $run_id"
    log "URL: $url"
    exit 1
  fi
  
  # Convert UTC time to local time, add error handling
  local formatted_time=""
  if [ -n "$updated_at" ]; then
    if [ "$(uname)" == "Darwin" ]; then
      formatted_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
      if [ $? -ne 0 ]; then
        # If conversion fails, use original time
        formatted_time="$updated_at"
      fi
    else
      formatted_time=$(date -d "$updated_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
      if [ $? -ne 0 ]; then
        # If conversion fails, use original time
        formatted_time="$updated_at"
      fi
    fi
  else
    formatted_time="Unknown time"
  fi
  
  # Build download links, ensure run_id exists
  local extension_download_url=""
  local binary_download_url=""
  
  if [ -n "$run_id" ]; then
    extension_download_url=$(get_nightly_link "$run_id" "$FILENAME")
    binary_download_url=$(get_nightly_link "$run_id" "$BINARY_FILENAME")
    
    log "Built extension download link: $extension_download_url"
    log "Built binary download link: $binary_download_url"
  else
    error "Could not obtain run ID, cannot build download links"
    exit 1
  fi
  
  # Create temporary JSON file
  local output_file=$(mktemp)
  
  # Use jq to create JSON and write to file
  jq -n \
    --arg run_id "$run_id" \
    --arg url "$url" \
    --arg display_title "${display_title:-Unknown title}" \
    --arg updated_at "$formatted_time" \
    --arg head_commit "${head_commit:-master}" \
    --arg extension_filename "$FILENAME" \
    --arg binary_filename "$BINARY_FILENAME" \
    --arg extension_download_url "$extension_download_url" \
    --arg binary_download_url "$binary_download_url" \
    '{
      run_id: $run_id,
      url: $url,
      display_title: $display_title,
      updated_at: $updated_at,
      head_commit: $head_commit,
      extension_filename: $extension_filename,
      binary_filename: $binary_filename,
      extension_download_url: $extension_download_url,
      binary_download_url: $binary_download_url
    }' > "$output_file"
  
  # Validate output JSON
  if ! jq empty < "$output_file" 2>/dev/null; then
    error "Could not create valid run info JSON"
    rm -f "$output_file"
    exit 1
  fi
  
  # Return JSON content and clean up temporary file
  cat "$output_file"
  rm -f "$output_file"
}

# Read repository package.json
read_repo_package_json() {
  local run_info="$1"
  local temp_run_info_file=""
  
  # Check if input is a file path or JSON string
  if [ -f "$run_info" ]; then
    temp_run_info_file="$run_info"
  else
    # Save JSON string to temporary file
    temp_run_info_file=$(mktemp)
    echo "$run_info" > "$temp_run_info_file"
    
    # Validate JSON format
    if ! jq empty < "$temp_run_info_file" 2>/dev/null; then
      error "Invalid run info JSON"
      rm -f "$temp_run_info_file"
      exit 1
    fi
  fi
  
  local head_commit=$(jq -r '.head_commit // "master"' < "$temp_run_info_file")
  if [ -z "$head_commit" ] || [ "$head_commit" = "null" ]; then
    warn "Could not get commit hash, will use master"
    head_commit="master"
  fi
  
  # Clean up if it was a temporarily created file
  if [ "$temp_run_info_file" != "$run_info" ]; then
    rm -f "$temp_run_info_file"
  fi
  
  local package_json_url="https://raw.githubusercontent.com/Myriad-Dreamin/tinymist/$head_commit/editors/vscode/package.json"
  
  # Get package.json and store temporarily
  local temp_package_json_file="$(mktemp)"
  
  # Status message, but ensure it doesn't get included in the return value
  log "Fetching package.json: $package_json_url"
  
  # Download file
  safe_curl "$package_json_url" "$temp_package_json_file"
  
  if [ ! -s "$temp_package_json_file" ]; then
    log "Error: Could not fetch package.json from $package_json_url"
    # Try to get default package.json
    log "Trying to fetch package.json from main branch..."
    safe_curl "$EXTENSION_PACKAGE_JSON_URL" "$temp_package_json_file"
    if [ ! -s "$temp_package_json_file" ]; then
      error "Could not fetch package information."
      rm -f "$temp_package_json_file"
      exit 1
    fi
  fi
  
  # Check if JSON is valid
  if ! jq empty < "$temp_package_json_file" 2>/dev/null; then
    error "Retrieved package.json is not valid JSON format"
    rm -f "$temp_package_json_file"
    exit 1
  fi
  
  # Return temporary file path, caller is responsible for handling and cleanup
  echo "$temp_package_json_file"
}

# Get artifact from run
get_artifact_from_run() {
  local run_info="$1"
  local file_name="$2"
  local download_url="$3"
  
  local temp_run_info_file=""
  
  # Determine if input is a file path or JSON string
  if [ -f "$run_info" ]; then
    temp_run_info_file="$run_info"
  else
    # Save JSON string to temporary file
    temp_run_info_file=$(mktemp)
    echo "$run_info" > "$temp_run_info_file"
    
    # Validate JSON format
    if ! jq empty < "$temp_run_info_file" 2>/dev/null; then
      error "Invalid run info JSON"
      rm -f "$temp_run_info_file"
      return 1
    fi
  fi
  
  # Check parameters
  if [ ! -s "$temp_run_info_file" ] || [ -z "$file_name" ] || [ -z "$download_url" ]; then
    error "Incomplete parameters required for artifact retrieval"
    log "Filename: $file_name"
    log "Download link: $download_url"
    
    # Clean up temporary file
    if [ "$temp_run_info_file" != "$run_info" ]; then
      rm -f "$temp_run_info_file"
    fi
    return 1
  fi
  
  # Get display information
  local display_title=$(jq -r '.display_title // "Unknown title"' < "$temp_run_info_file")
  local updated_at=$(jq -r '.updated_at // "Unknown time"' < "$temp_run_info_file")
  local url=$(jq -r '.url // "No URL"' < "$temp_run_info_file")
  
  log "Title: $display_title"
  log "Build time: $updated_at"
  log "More info: $url"
  
  if jq -e 'has("prUrl")' < "$temp_run_info_file" > /dev/null; then
    local pr_url=$(jq -r '.prUrl' < "$temp_run_info_file")
    log "Related PR: $pr_url"
  fi
  
  # Clean up temporary file
  if [ "$temp_run_info_file" != "$run_info" ]; then
    rm -f "$temp_run_info_file"
  fi
  
  log ""
  log "Downloading $file_name:"
  log "$download_url"
  log ""
  
  # Create temporary directory for download and extraction
  local temp_dir=$(mktemp -d)
  log "Created temporary directory: $temp_dir"
  
  # Set file paths
  local file_path="$temp_dir/$file_name"
  local file_zip_path="$temp_dir/${file_name}.zip"
  
  log "Downloading to file $file_zip_path..."
  safe_download "$download_url" "$file_zip_path"
  if [ $? -ne 0 ]; then
    error "File download failed: $download_url"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Check downloaded file size
  if [ ! -f "$file_zip_path" ]; then
    error "Downloaded file does not exist: $file_zip_path"
    rm -rf "$temp_dir"
    return 1
  fi
  
  local file_size=$(wc -c < "$file_zip_path")
  if [ "$file_size" -lt 1000 ]; then
    warn "Downloaded file is too small (${file_size} bytes), might not be valid"
    log "File content:"
    cat "$file_zip_path" | head -n 10 >&2
  fi
  
  # Check if zip file is valid
  if ! unzip -t "$file_zip_path" > /dev/null 2>&1; then
    log "Error: Downloaded file is not a valid zip file"
    log "Trying to use downloaded file directly..."
    # May be a direct non-compressed file download, try to use directly
    if [ -s "$file_zip_path" ]; then
      mv "$file_zip_path" "$file_path"
      chmod +x "$file_path"
      log "Artifact file prepared: $file_path"
      
      # Create final output file, which is an absolute path to the temporary directory
      echo "$file_path"
      return 0
    else
      rm -f "$file_zip_path"
      rm -rf "$temp_dir"
      return 1
    fi
  fi
  
  log "Extracting file to temporary directory..."
  # Extract to temporary directory, avoid file conflicts in current directory
  unzip -qq "$file_zip_path" -d "$temp_dir"
  if [ $? -ne 0 ]; then
    error "Cannot extract file: $file_zip_path"
    rm -f "$file_zip_path"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Find extracted file
  log "Looking for $file_name in temporary directory"
  local extracted_file=$(find "$temp_dir" -name "$file_name" -type f)
  if [ -z "$extracted_file" ]; then
    warn "Could not find $file_name in extracted files"
    log "Contents of extraction directory:"
    ls -la "$temp_dir" >&2
    
    # Try to find any possible matching file
    log "Trying to find any possible matching file..."
    local any_file=$(find "$temp_dir" -type f | grep -v "\.zip$" | head -1)
    if [ -n "$any_file" ]; then
      log "Found file: $any_file"
      mv "$any_file" "$file_path"
      chmod +x "$file_path" # Ensure file has execution permissions
    else
      error "Could not find any files in temporary directory"
      rm -f "$file_zip_path"
      rm -rf "$temp_dir"
      return 1
    fi
  else
    log "Found file: $extracted_file"
    # If found file but not in expected location, move it
    if [ "$extracted_file" != "$file_path" ]; then
      mv "$extracted_file" "$file_path"
    fi
    chmod +x "$file_path" # Ensure file has execution permissions
  fi
  
  # Clean up unnecessary files
  rm -f "$file_zip_path"
  find "$temp_dir" -type f -not -path "$file_path" -delete 2>/dev/null
  
  # Confirm file exists
  if [ ! -f "$file_path" ]; then
    error "Artifact file was not properly prepared: $file_path"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Ensure file is accessible
  if [ ! -r "$file_path" ]; then
    error "Artifact file cannot be read: $file_path"
    rm -rf "$temp_dir"
    return 1
  fi
  
  local final_size=$(wc -c < "$file_path")
  log "Artifact file prepared: $file_path (${final_size} bytes)"
  
  # Only output result, don't add any extra information
  echo "$file_path"
  return 0
}

# Get extension file from release
get_extension_file_from_release() {
  local file_name="${1:-$FILENAME}"
  
  log "Checking latest stable version..."
  log ""
  
  # Create temporary file to store API response
  local response_file=$(mktemp)
  safe_curl "$RELEASE_URL" "$response_file"
  
  if [ $? -ne 0 ] || [ ! -s "$response_file" ]; then
    error "Failed to get stable version information"
    rm -f "$response_file"
    exit 1
  fi
  
  # Validate JSON format
  if ! jq empty < "$response_file" 2>/dev/null; then
    error "Retrieved release info is not valid JSON format"
    rm -f "$response_file"
    exit 1
  fi
  
  # Read data from temporary file
  local tag=$(jq -r '.tag_name // "Unknown version"' < "$response_file")
  local updated_at=$(jq -r '.published_at // ""' < "$response_file")
  local url=$(jq -r '.html_url // "#"' < "$response_file")
  
  # Convert UTC time to local time
  local formatted_time="Unknown time"
  if [ -n "$updated_at" ]; then
    if [ "$(uname)" == "Darwin" ]; then
      formatted_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
      if [ $? -ne 0 ]; then
        formatted_time="$updated_at"
      fi
    else
      formatted_time=$(date -d "$updated_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
      if [ $? -ne 0 ]; then
        formatted_time="$updated_at"
      fi
    fi
  fi
  
  # Create temporary file to store download URL
  local url_file=$(mktemp)
  jq --arg name "$file_name" -r '.assets[] | select(.name == $name) | .browser_download_url' < "$response_file" > "$url_file"
  
  if [ ! -s "$url_file" ]; then
    error "Could not find $file_name in release assets"
    # Display available asset names
    log "Available assets:"
    jq -r '.assets[].name' < "$response_file" >&2
    rm -f "$response_file" "$url_file"
    exit 1
  fi
  
  local download_url=$(cat "$url_file")
  rm -f "$url_file"
  
  # Create temporary directory
  local temp_dir=$(mktemp -d)
  local file_path="$temp_dir/$file_name"
  
  log "Version: $tag"
  log "Release date: $formatted_time"
  log "More info: $url"
  log ""
  log "Downloading $file_name:"
  log "$download_url"
  log ""
  
  safe_download "$download_url" "$file_path"
  if [ $? -ne 0 ]; then
    error "File download failed: $download_url"
    rm -rf "$temp_dir"
    rm -f "$response_file"
    exit 1
  fi
  
  if [ ! -f "$file_path" ] || [ ! -s "$file_path" ]; then
    error "Downloaded file does not exist or is empty: $file_path"
    rm -rf "$temp_dir"
    rm -f "$response_file"
    exit 1
  fi
  
  # Clean up response file
  rm -f "$response_file"
  
  log "Extension file prepared: $file_path"
  echo "$file_path"
}

# Test VS Code version requirement
test_vscode_requirement() {
  local vscode_require="$1"
  
  if [ -z "$vscode_require" ]; then
    warn "VS Code version requirement not found, will skip compatibility check"
    return 0
  fi
  
  log ""
  log "VS Code version requirement: $vscode_require"
  
  # Check if VS Code is installed
  if ! command -v code >/dev/null 2>&1; then
    error "VS Code not found. Please ensure VS Code is installed and in PATH."
    exit 1
  fi
  
  # Check extension compatibility with current VS Code version
  local vs_code_version
  vs_code_version=$(code --version | head -1)
  if [ $? -ne 0 ] || [ -z "$vs_code_version" ]; then
    warn "Could not get VS Code version, will skip compatibility check"
    return 0
  fi
  
  log "VS Code installed version: $vs_code_version"
  log ""
  
  # Extract minimum required version (remove ^, ~, >, =, < prefixes)
  local min_version
  min_version=$(echo "$vscode_require" | sed 's/[\^~>=<]//g')
  if [ -z "$min_version" ]; then
    warn "Could not parse version requirement, will skip compatibility check"
    return 0
  fi
  
  # Compare versions
  if ! [ "$(printf '%s\n' "$min_version" "$vs_code_version" | sort -V | head -n1)" = "$min_version" ]; then
    error "VS Code version mismatch, please update to at least $min_version"
    exit 1
  fi
  
  log "Version compatibility check passed"
}

# Install extension
install_extension() {
  local extension_path="$1"
  
  if [ -z "$extension_path" ] || [ ! -f "$extension_path" ]; then
    error "Invalid extension file path - $extension_path"
    exit 1
  fi
  
  local file_name=$(basename "$extension_path")
  
  log "Installing VS Code extension: $file_name"
  # Install VS Code extension
  code --install-extension "$extension_path"
  
  if [ $? -eq 0 ]; then
    log "✅ VS Code extension installed successfully: $file_name"
    log "Please reload VS Code to activate the extension"
  else
    error "❌ VS Code extension installation failed"
    exit 1
  fi
}

# Install binary
install_binary() {
  local binary_path="$1"
  local file_name="${2:-$(basename "$binary_path")}"
  
  if [ -z "$binary_path" ] || [ ! -f "$binary_path" ]; then
    error "Invalid binary file path - $binary_path"
  exit 1
fi

  local local_bin_dir="$HOME/.local/bin"
  local local_bin_path="$local_bin_dir/$file_name"
  
  log "Installing binary to $local_bin_path"
  
  if [ ! -d "$local_bin_dir" ]; then
    log "Creating directory $local_bin_dir"
    mkdir -p "$local_bin_dir"
  fi
  
  if [ -f "$local_bin_path" ]; then
    log "Removing old version..."
    rm -f "$local_bin_path"
  fi
  
  cp "$binary_path" "$local_bin_path"
  chmod +x "$local_bin_path"
  
  log "Testing binary..."
  local bin_version=$("$local_bin_path" --version 2>/dev/null)
  if [ $? -ne 0 ]; then
    error "❌ Binary installation is invalid: $local_bin_path"
    exit 1
  fi
  
  log "✅ Binary installed successfully: $local_bin_path"
  log "Version: $bin_version"
  log "Please ensure $local_bin_dir is in your PATH environment variable"
  
  # Check if .local/bin is in PATH
  if ! echo "$PATH" | grep -q "$local_bin_dir"; then
    log ""
    log "Note: $local_bin_dir does not appear to be in your PATH"
    log "You can fix this by adding the following line to your shell configuration file:"
    log ""
    log "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    log ""
    if [ -f "$HOME/.zshrc" ]; then
      log "For example, add it to your ~/.zshrc file"
    elif [ -f "$HOME/.bashrc" ]; then
      log "For example, add it to your ~/.bashrc file"
    fi
  fi
}

# Get latest nightly run info
get_latest_nightly_run_info() {
  # Create temporary file to store API response
  local response_file=$(mktemp)
  local curl_exit_code=0
  
  # Add GitHub API user agent header to avoid request limitation
  safe_curl "$NIGHTLY_URL" "$response_file" || curl_exit_code=$?
  
  if [ $curl_exit_code -ne 0 ] || [ ! -s "$response_file" ]; then
    error "Could not get nightly build information."
    rm -f "$response_file"
    exit 1
  fi
  
  # Verify response is valid JSON
  if ! jq empty < "$response_file" 2>/dev/null; then
    error "Response from GitHub API is not valid JSON."
    log "API response: $(head -c 100 "$response_file")..."
    rm -f "$response_file"
    exit 1
  fi
  
  # Check if rate limited by API
  if jq -e 'has("message")' < "$response_file" > /dev/null; then
    local message=$(jq -r '.message' < "$response_file")
    error "GitHub API returned error: $message"
    rm -f "$response_file"
    exit 1
  fi
  
  # Check if there are workflow runs
  local total_count=$(jq -r '.total_count // 0' < "$response_file")
  if [ "$total_count" -eq 0 ]; then
    error "No workflow runs available."
    rm -f "$response_file"
    exit 1
  fi
  
  # Extract first workflow run to separate temporary file
  local workflow_file=$(mktemp)
  jq '.workflow_runs[0]' < "$response_file" > "$workflow_file"
  
  if [ ! -s "$workflow_file" ] || [ "$(cat "$workflow_file")" = "null" ]; then
    error "Could not get workflow run data."
    rm -f "$response_file" "$workflow_file"
    exit 1
  fi
  
  # Clean up initial response file
  rm -f "$response_file"
  
  # Use temporary file as input
  local run_info=$(get_run_info "$workflow_file")
  
  # Clean up workflow file
  rm -f "$workflow_file"
  
  echo "$run_info"
}

# Install extension from run information
install_extension_from_run_info() {
  local run_info="$1"
  local temp_run_info_file=""
  
  # Determine if input is file path or JSON string
  if [ -f "$run_info" ]; then
    temp_run_info_file="$run_info"
  else
    # Save JSON string to temporary file
    temp_run_info_file=$(mktemp)
    echo "$run_info" > "$temp_run_info_file"
    
    # Validate JSON format
    if ! jq empty < "$temp_run_info_file" 2>/dev/null; then
      error "Invalid run info JSON"
      rm -f "$temp_run_info_file"
      exit 1
    fi
  fi

  # Print debug information
  log "Retrieved run information:"
  jq '.' < "$temp_run_info_file" >&2
  
  # read_repo_package_json now returns temporary file path
  local package_json_file=$(read_repo_package_json "$temp_run_info_file")
  
  # Directly read version requirement from file, keep original format
  local vscode_requirement=$(jq -r '.engines.vscode // ""' < "$package_json_file")
  
  # Clean up temporary file
  rm -f "$package_json_file"
  
  test_vscode_requirement "$vscode_requirement"
  
  log "Getting extension from run information..."
  
  # Extract required information
  local extension_filename=$(jq -r '.extension_filename // ""' < "$temp_run_info_file")
  local extension_download_url=$(jq -r '.extension_download_url // ""' < "$temp_run_info_file")
  
  # Clean up if it was a temporary created file
  if [ "$temp_run_info_file" != "$run_info" ]; then
    rm -f "$temp_run_info_file"
  fi
  
  if [ -z "$extension_filename" ] || [ -z "$extension_download_url" ]; then
    error "Could not get extension filename or download URL from run information"
    log "Extension filename: $extension_filename"
    log "Download URL: $extension_download_url"
    exit 1
  fi
  
  # Use command substitution to capture function standard output, don't use pipe
  local extension_path=$(get_artifact_from_run "$run_info" "$extension_filename" "$extension_download_url")
  local get_artifact_result=$?
  
  log "Captured extension file path: $extension_path (exit status: $get_artifact_result)"
  
  if [ $get_artifact_result -ne 0 ] || [ -z "$extension_path" ]; then
    error "Could not get extension file, get_artifact_from_run returned non-zero status or empty path"
    exit 1
  fi
  
  # Verify file actually exists
  if [ ! -f "$extension_path" ]; then
    error "Extension file does not exist: $extension_path"
    exit 1
  fi
  
  # Verify file size
  local file_size=$(wc -c < "$extension_path")
  log "Extension file size: ${file_size} bytes"
  
  # Extract temporary directory path where extension file is located
  local temp_dir=$(dirname "$extension_path")
  
  # Install extension
  install_extension "$extension_path"
  
  # Clean up temporary directory
  if [[ "$temp_dir" == *"/tmp/"* ]] || [[ "$temp_dir" == *"/var/folders/"* ]]; then
    log "Cleaning up temporary directory: $temp_dir"
    rm -rf "$temp_dir"
  else
    warn "File path not in temporary directory, skipping automatic cleanup: $temp_dir"
    rm -f "$extension_path"
  fi
}

# Install binary
install_binary_from_run_info() {
  local run_info="$1"
  local temp_run_info_file=""
  
  # Determine if input is file path or JSON string
  if [ -f "$run_info" ]; then
    temp_run_info_file="$run_info"
  else
    # Save JSON string to temporary file
    temp_run_info_file=$(mktemp)
    echo "$run_info" > "$temp_run_info_file"
    
    # Validate JSON format
    if ! jq empty < "$temp_run_info_file" 2>/dev/null; then
      error "Invalid run info JSON"
      rm -f "$temp_run_info_file"
      exit 1
    fi
  fi
  
  # Print debug information
  log "Retrieved run information:"
  jq '.' < "$temp_run_info_file" >&2
  
  log "Getting binary from run information..."
  
  # Extract required information
  local binary_filename=$(jq -r '.binary_filename // ""' < "$temp_run_info_file")
  local binary_download_url=$(jq -r '.binary_download_url // ""' < "$temp_run_info_file")
  
  # Clean up if it was a temporary created file
  if [ "$temp_run_info_file" != "$run_info" ]; then
    rm -f "$temp_run_info_file"
  fi
  
  if [ -z "$binary_filename" ] || [ -z "$binary_download_url" ]; then
    error "Could not get binary filename or download URL from run information"
    log "Binary filename: $binary_filename"
    log "Download URL: $binary_download_url"
    exit 1
  fi
  
  # Use command substitution to capture function standard output, don't use pipe
  local binary_path=$(get_artifact_from_run "$run_info" "$binary_filename" "$binary_download_url")
  local get_artifact_result=$?
  
  log "Captured binary file path: $binary_path (exit status: $get_artifact_result)"
  
  if [ $get_artifact_result -ne 0 ] || [ -z "$binary_path" ]; then
    error "Could not get binary file, get_artifact_from_run returned non-zero status or empty path"
    exit 1
  fi
  
  # Verify file actually exists
  if [ ! -f "$binary_path" ]; then
    error "Binary file does not exist: $binary_path"
    exit 1
  fi
  
  # Verify file size
  local file_size=$(wc -c < "$binary_path")
  log "Binary file size: ${file_size} bytes"
  
  # Extract temporary directory path where binary file is located
  local temp_dir=$(dirname "$binary_path")
  
  # Install binary file
  install_binary "$binary_path" "tinymist"
  
  # Clean up temporary directory
  if [[ "$temp_dir" == *"/tmp/"* ]] || [[ "$temp_dir" == *"/var/folders/"* ]]; then
    log "Cleaning up temporary directory: $temp_dir"
    rm -rf "$temp_dir"
  else
    warn "File path not in temporary directory, skipping automatic cleanup: $temp_dir"
    rm -f "$binary_path"
  fi
}

# Install artifact from run information
install_artifact_from_run_info() {
  local run_info="$1"
  local artifact_name="$2"
  
  local temp_run_info_file=""
  
  # Determine if input is file path or JSON string
  if [ -f "$run_info" ]; then
    temp_run_info_file="$run_info"
  else
    # Save JSON string to temporary file
    temp_run_info_file=$(mktemp)
    echo "$run_info" > "$temp_run_info_file"
    
    # Validate JSON format
    if ! jq empty < "$temp_run_info_file" 2>/dev/null; then
      error "Invalid run info JSON"
      rm -f "$temp_run_info_file"
      exit 1
    fi
  fi
  
  if [ -z "$artifact_name" ]; then
    error "Valid artifact name required for installation"
    if [ "$temp_run_info_file" != "$run_info" ]; then
      rm -f "$temp_run_info_file"
    fi
    exit 1
  fi
  
  log "Installing $artifact_name from run information..."
  
  if [ "$artifact_name" = "extension" ]; then
    install_extension_from_run_info "$temp_run_info_file"
  elif [ "$artifact_name" = "binary" ]; then
    install_binary_from_run_info "$temp_run_info_file"
  else
    error "Invalid artifact name: $artifact_name (must be 'extension' or 'binary')"
    if [ "$temp_run_info_file" != "$run_info" ]; then
      rm -f "$temp_run_info_file"
    fi
    exit 1
  fi
  
  # Clean up temporary file
  if [ "$temp_run_info_file" != "$run_info" ]; then
    rm -f "$temp_run_info_file"
  fi
}

# Install latest nightly artifact
install_latest_nightly_artifact() {
  local artifact_name="$1"
  
  if [ -z "$artifact_name" ]; then
    error "Missing artifact name"
    exit 1
  fi
  
  log "Installing latest nightly $artifact_name..."
  log "Checking latest nightly build..."
  
  local run_info=$(get_latest_nightly_run_info)
  install_artifact_from_run_info "$run_info" "$artifact_name"
}

# Install latest stable artifact
install_latest_stable_artifact() {
  local artifact_name="$1"
  
  if [ -z "$artifact_name" ]; then
    error "Missing artifact name"
    exit 1
  fi
  
  log "Installing latest stable $artifact_name..."
  
  if [ "$artifact_name" = "extension" ]; then
    local extension_path=$(get_extension_file_from_release)
    local temp_dir=$(dirname "$extension_path")
    
    install_extension "$extension_path"
    
    # Clean up temporary directory
    if [[ "$temp_dir" == *"/tmp/"* ]] || [[ "$temp_dir" == *"/var/folders/"* ]]; then
      log "Cleaning up temporary directory: $temp_dir"
      rm -rf "$temp_dir"
    else
      warn "File path not in temporary directory, skipping automatic cleanup: $temp_dir"
      rm -f "$extension_path"
    fi
  elif [ "$artifact_name" = "binary" ]; then
    local binary_path=$(get_extension_file_from_release "$BINARY_FILENAME")
    local temp_dir=$(dirname "$binary_path")
    
    install_binary "$binary_path" "tinymist"
    
    # Clean up temporary directory
    if [[ "$temp_dir" == *"/tmp/"* ]] || [[ "$temp_dir" == *"/var/folders/"* ]]; then
      log "Cleaning up temporary directory: $temp_dir"
      rm -rf "$temp_dir"
    else
      warn "File path not in temporary directory, skipping automatic cleanup: $temp_dir"
      rm -f "$binary_path"
    fi
  else
    error "Invalid artifact name: $artifact_name (must be 'extension' or 'binary')"
    exit 1
  fi
}

# Install artifact by run ID
install_artifact_by_run_id() {
  local run_id="$1"
  local artifact_name="$2"
  
  if [ -z "$run_id" ] || [ -z "$artifact_name" ]; then
    error "Valid run ID and artifact name required for installation"
    exit 1
  fi
  
  log "Installing $artifact_name from run ID $run_id..."
  
  local info_url="https://api.github.com/repos/myriad-dreamin/tinymist/actions/runs/$run_id"
  local response_file=$(mktemp)
  
  # Add GitHub API user agent header to avoid request limitation
  safe_curl "$info_url" "$response_file"
  
  if [ $? -ne 0 ] || [ ! -s "$response_file" ]; then
    error "Could not get run information: $run_id"
    rm -f "$response_file"
    exit 1
  fi
  
  # Check if run was found
  if jq -e 'has("message")' < "$response_file" > /dev/null; then
    local message=$(jq -r '.message' < "$response_file")
    error "$message"
    rm -f "$response_file"
    exit 1
  fi
  
  # Process run information, save result to temporary file
  local run_info_file=$(mktemp)
  get_run_info "$response_file" > "$run_info_file"
  
  # Clean up response file
  rm -f "$response_file"
  
  # Use file path to pass to install_artifact_from_run_info
  install_artifact_from_run_info "$run_info_file" "$artifact_name"
  
  # Clean up temporary file
  rm -f "$run_info_file"
}

# Install artifact by PR number
install_artifact_by_pr_number() {
  local pr_number="$1"
  local artifact_name="$2"
  
  if [ -z "$pr_number" ] || [ -z "$artifact_name" ]; then
    error "Valid PR number and artifact name required for installation"
    exit 1
  fi
  
  log "Installing $artifact_name from PR #$pr_number..."
  
  local pr_info_url="https://api.github.com/repos/myriad-dreamin/tinymist/pulls/$pr_number"
  local pr_file=$(mktemp)
  
  # Add GitHub API user agent header to avoid request limitation
  safe_curl "$pr_info_url" "$pr_file"
  
  if [ $? -ne 0 ] || [ ! -s "$pr_file" ]; then
    error "Could not get PR information: $pr_number"
    rm -f "$pr_file"
    exit 1
  fi
  
  # Check if PR was found
  if jq -e 'has("message")' < "$pr_file" > /dev/null; then
    local message=$(jq -r '.message' < "$pr_file")
    error "$message"
    rm -f "$pr_file"
    exit 1
  fi
  
  local pr_head_sha=$(jq -r '.head.sha // ""' < "$pr_file")
  if [ -z "$pr_head_sha" ]; then
    error "Could not get commit hash for PR"
    rm -f "$pr_file"
    exit 1
  fi
  
  local sha_runs_url="https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&head_sha=$pr_head_sha&status=success"
  local runs_file=$(mktemp)
  
  # Add GitHub API user agent header to avoid request limitation
  safe_curl "$sha_runs_url" "$runs_file"
  
  if [ $? -ne 0 ] || [ ! -s "$runs_file" ]; then
    error "Could not get PR workflow run information"
    rm -f "$pr_file" "$runs_file"
    exit 1
  fi
  
  local total_count=$(jq -r '.total_count // 0' < "$runs_file")
  if [ "$total_count" -eq 0 ]; then
    error "No successful workflow runs found for PR #$pr_number"
    rm -f "$pr_file" "$runs_file"
    exit 1
  fi
  
  # Extract workflow run
  local workflow_file=$(mktemp)
  jq '.workflow_runs[0]' < "$runs_file" > "$workflow_file"
  
  if [ ! -s "$workflow_file" ] || [ "$(cat "$workflow_file")" = "null" ]; then
    error "Could not get workflow run for PR"
    rm -f "$pr_file" "$runs_file" "$workflow_file"
    exit 1
  fi
  
  # Get run information
  local run_info=$(get_run_info "$workflow_file")
  local run_info_file=$(mktemp)
  echo "$run_info" > "$run_info_file"
  
  # Get PR title
  local pr_title=$(jq -r '.title // "Unknown title"' < "$pr_file")
  local pr_url=$(jq -r '.html_url' < "$pr_file")
  local display_title="PR #$pr_number $pr_title - $(jq -r '.display_title // "Unknown run"' < "$run_info_file")"
  
  # Create temporary file to store updated run info
  local updated_run_info_file=$(mktemp)
  jq --arg title "$display_title" --arg url "$pr_url" '. + {display_title: $title, prUrl: $url}' < "$run_info_file" > "$updated_run_info_file"
  
  # Clean up temporary files
  rm -f "$pr_file" "$runs_file" "$workflow_file" "$run_info_file"
  
  # Use file path to pass to install_artifact_from_run_info
  install_artifact_from_run_info "$updated_run_info_file" "$artifact_name"
  
  # Clean up last temporary file
  rm -f "$updated_run_info_file"
}

# Main logic

# Parse command line arguments
ARTIFACT_NAME="extension"
BUILD="--nightly"
RUN_ID=""
PR_NUMBER=""

if [ $# -gt 0 ]; then
  if [ "$1" = "extension" ] || [ "$1" = "binary" ]; then
    ARTIFACT_NAME="$1"
    shift
  fi
  
  if [ $# -gt 0 ]; then
    BUILD="$1"
    shift
    
    if [ $# -gt 0 ] && ([ "$BUILD" = "--run" ] || [ "$BUILD" = "--pr" ]); then
      if [ "$BUILD" = "--run" ]; then
        RUN_ID="$1"
        # Validate run ID is numeric
        if ! [[ "$RUN_ID" =~ ^[0-9]+$ ]]; then
          echo "Error: Invalid run ID: $RUN_ID" >&2
          exit 1
        fi
      elif [ "$BUILD" = "--pr" ]; then
        PR_NUMBER="$1"
        # Validate PR number is numeric
        if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
          echo "Error: Invalid PR number: $PR_NUMBER" >&2
          exit 1
        fi
      fi
      shift
    fi
  fi
fi

# Check dependency tools
for cmd in curl jq unzip; do
  if ! command -v $cmd &> /dev/null; then
    error "Required command '$cmd' not found"
    log "Please install it before running this script"
    exit 1
  fi
done

# Execute appropriate installation command
if [ "$BUILD" = "--stable" ]; then
  print_system_info
  install_latest_stable_artifact "$ARTIFACT_NAME"
elif [ "$BUILD" = "--nightly" ]; then
  print_system_info
  install_latest_nightly_artifact "$ARTIFACT_NAME"
elif [ "$BUILD" = "--run" ] && [ -n "$RUN_ID" ]; then
  print_system_info
  install_artifact_by_run_id "$RUN_ID" "$ARTIFACT_NAME"
elif [ "$BUILD" = "--pr" ] && [ -n "$PR_NUMBER" ]; then
  print_system_info
  install_artifact_by_pr_number "$PR_NUMBER" "$ARTIFACT_NAME"
else
  print_help
fi
