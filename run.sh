#!/bin/bash

function print_help() {
  echo "Usage: $0 [extension|binary] [--stable|--nightly|--run <run_id>|--pr <pr_number>]"
  echo "Defaulting to nightly build without arguments."
  echo ""
  echo " --stable: Install the latest stable release"
  echo " --nightly: Install the latest nightly build"
  echo " --run: Install from a specific workflow run ID"
  echo " --pr: Install from a specific pull request"
  echo ""
  echo "Examples:"
  echo " $0 --stable"
  echo " $0 --nightly"
  echo " $0 --run 13916708000"
  echo " $0 binary --run 13916708000" 
  echo " $0 binary --pr 1500"
  echo ""
}

# Parse command line arguments
ARTIFACT_NAME="extension"
BUILD_TYPE="--nightly"
RUN_ID=""
PR_NUMBER=""

if [ $# -gt 0 ]; then
  if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    print_help
    exit 0
  elif [ "$1" == "--stable" ] || [ "$1" == "--nightly" ] || [ "$1" == "--run" ] || [ "$1" == "--pr" ]; then
    BUILD_TYPE="$1"
    if [ "$BUILD_TYPE" == "--run" ] && [ $# -gt 1 ]; then
      RUN_ID="$2"
      # Check if RUN_ID is a number
      if ! [[ "$RUN_ID" =~ ^[0-9]+$ ]]; then
        echo "Invalid run ID: $RUN_ID"
        exit 1
      fi
    elif [ "$BUILD_TYPE" == "--pr" ] && [ $# -gt 1 ]; then
      PR_NUMBER="$2"
      # Check if PR_NUMBER is a number
      if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
        echo "Invalid PR number: $PR_NUMBER"
        exit 1
      fi
    fi
  else
    ARTIFACT_NAME="$1"
    if [ "$ARTIFACT_NAME" != "extension" ] && [ "$ARTIFACT_NAME" != "binary" ]; then
      print_help
      exit 1
    fi
    if [ $# -gt 1 ]; then
      BUILD_TYPE="$2"
      if [ "$BUILD_TYPE" == "--run" ] && [ $# -gt 2 ]; then
        RUN_ID="$3"
        # Check if RUN_ID is a number
        if ! [[ "$RUN_ID" =~ ^[0-9]+$ ]]; then
          echo "Invalid run ID: $RUN_ID"
          exit 1
        fi
      elif [ "$BUILD_TYPE" == "--pr" ] && [ $# -gt 2 ]; then
        PR_NUMBER="$3"
        # Check if PR_NUMBER is a number
        if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
          echo "Invalid PR number: $PR_NUMBER"
          exit 1
        fi
      fi
    fi
  fi
fi

DOWNLOAD_DIR="."

UNAME=$(uname | tr '[:upper:]' '[:lower:]')
UNAME_M=$(uname -m | tr '[:upper:]' '[:lower:]')

echo "Your system is $UNAME-$UNAME_M"

FILENAME="tinymist-$UNAME-$UNAME_M.vsix"
BINARY_FILENAME="tinymist-$UNAME-$UNAME_M"
ZIPFILE="$DOWNLOAD_DIR/$FILENAME.zip"
BINARY_ZIPFILE="$DOWNLOAD_DIR/$BINARY_FILENAME.zip"
NIGHTLY_URL="https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
RELEASE_URL="https://api.github.com/repos/myriad-dreamin/tinymist/releases"
EXTENSION_PACKAGE_JSON_URL="https://raw.githubusercontent.com/Myriad-Dreamin/tinymist/refs/heads/main/editors/vscode/package.json"

function get_nightly_link() {
  local run_id="$1"
  local filename="$2"
  echo "https://nightly.link/Myriad-Dreamin/tinymist/actions/runs/$run_id/$filename.zip"
}

function get_run_info() {
  local run_json="$1"
  local run_id=$(echo "$run_json" | jq -r '.id')
  local head_commit=$(echo "$run_json" | jq -r '.head_commit.id')
  local display_title=$(echo "$run_json" | jq -r '.display_title')
  local updated_at=$(echo "$run_json" | jq -r '.updated_at')
  local url=$(echo "$run_json" | jq -r '.html_url')
  
  # Convert UTC time to local time
  if [ "$(uname)" == "Darwin" ]; then
    updated_at=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" "+%Y-%m-%d %H:%M:%S")
  else
    updated_at=$(date -d "$updated_at" "+%Y-%m-%d %H:%M:%S")
  fi
  
  local extension_download_url=$(get_nightly_link "$run_id" "$FILENAME")
  local binary_download_url=$(get_nightly_link "$run_id" "$BINARY_FILENAME")
  
  echo "{\"run_id\": \"$run_id\", \"url\": \"$url\", \"display_title\": \"$display_title\", \"updated_at\": \"$updated_at\", \"head_commit\": \"$head_commit\", \"extension_download_url\": \"$extension_download_url\", \"binary_download_url\": \"$binary_download_url\"}"
}

function read_repo_package_json() {
  local run_info="$1"
  local head_commit=$(echo "$run_info" | jq -r '.head_commit')
  local package_json_url="https://raw.githubusercontent.com/Myriad-Dreamin/tinymist/$head_commit/editors/vscode/package.json"
  
  curl -s "$package_json_url"
}

function get_artifact_from_run() {
  local run_info="$1"
  local file_name="$2"
  local download_url="$3"
  local file_path="$DOWNLOAD_DIR/$file_name"
  local file_zip_path="$file_path.zip"
  local display_title=$(echo "$run_info" | jq -r '.display_title')
  local updated_at=$(echo "$run_info" | jq -r '.updated_at')
  local url=$(echo "$run_info" | jq -r '.url')
  local pr_url=$(echo "$run_info" | jq -r '.pr_url // empty')
  
  echo "Title: $display_title"
  echo "Build Time: $updated_at"
  echo "For more information, visit: $url"
  if [ -n "$pr_url" ]; then
    echo "Related PR: $pr_url"
  fi
  echo ""
  echo "Downloading $file_name from $download_url"
  echo ""
  
  curl -sL -o "$file_zip_path" "$download_url"
  if [ $? -ne 0 ]; then
    echo "File download failed: $download_url"
    exit 1
  fi
  
  if [ -f "$file_path" ]; then
    rm -f "$file_path"
  fi
  
  unzip -qq "$file_zip_path" -d "$DOWNLOAD_DIR"
  if [ $? -ne 0 ]; then
    echo "Failed to unzip file: $file_zip_path"
    exit 1
  fi
  
  echo "File downloaded and unzipped to $file_path"
  rm -f "$file_zip_path"
  
  echo "$file_path"
}

function test_vscode_requirement() {
  local vscode_require="$1"
  
  echo ""
  echo "VS Code version required: $vscode_require"
  
  # Check if the extension is compatible with the current version of VS Code
  VS_CODE_VERSION=$(code --version | head -1)
  echo "VS Code version installed: $VS_CODE_VERSION"
  echo ""
  
  # Extract minimum required version (remove ^ and any other prefixes)
  MIN_VERSION=$(echo "$vscode_require" | sed 's/[\^~>=<]//g')
  INSTALLED_VERSION="$VS_CODE_VERSION"
  
  # Compare versions
  if ! [ "$(printf '%s\n' "$MIN_VERSION" "$INSTALLED_VERSION" | sort -V | head -n1)" = "$MIN_VERSION" ]; then
    echo "VS Code version mismatch, please update to at least $MIN_VERSION"
    exit 1
  fi
}

function install_extension() {
  local extension_path="$1"
  local file_name=$(basename "$extension_path")
  echo "Installing VS Code extension from $extension_path"
  
  code --install-extension "$extension_path"
  
  if [ $? -eq 0 ]; then
    echo "VS Code extension installed successfully: $file_name"
    echo "Please reload VS Code to activate the extension"
  else
    echo "VS Code extension installation failed"
  fi
}

function install_binary() {
  local binary_path="$1"
  local file_name=$(basename "$binary_path")
  
  local local_bin_dir="$HOME/.local/bin"
  local local_bin_path="$local_bin_dir/$file_name"
  
  if [ ! -d "$local_bin_dir" ]; then
    mkdir -p "$local_bin_dir"
  fi
  
  if [ -f "$local_bin_path" ]; then
    rm -f "$local_bin_path"
  fi
  
  cp "$binary_path" "$local_bin_path"
  chmod +x "$local_bin_path"
  
  if ! "$local_bin_path" --version &>/dev/null; then
    echo "Binary file installation is not valid: $local_bin_path"
    exit 1
  fi
  
  echo "Binary file installed successfully: $local_bin_path"
  "$local_bin_path" --version
  echo "Please make sure $local_bin_dir is in your PATH"
}

function get_latest_nightly_run_info() {
  local info_url="$NIGHTLY_URL"
  local nightly_json=$(curl -s "$info_url")
  
  get_run_info "$(echo "$nightly_json" | jq -r '.workflow_runs[0]')"
}

function install_extension_from_run_info() {
  local run_info="$1"
  local package_json=$(read_repo_package_json "$run_info")
  local vscode_require=$(echo "$package_json" | jq -r '.engines.vscode')
  
  test_vscode_requirement "$vscode_require"
  
  local extension_path=$(get_artifact_from_run "$run_info" "$FILENAME" "$(echo "$run_info" | jq -r '.extension_download_url')")
  install_extension "$extension_path"
  rm -f "$extension_path"
}

function install_binary_from_run_info() {
  local run_info="$1"
  
  # Get the correct binary filename for the current platform
  if [ "$UNAME" = "darwin" ]; then
    BINARY_NAME="tinymist"
  else
    BINARY_NAME="tinymist"
  fi
  
  local binary_path=$(get_artifact_from_run "$run_info" "$BINARY_FILENAME" "$(echo "$run_info" | jq -r '.binary_download_url')")
  install_binary "$binary_path" "$BINARY_NAME"
  rm -f "$binary_path"
}

function install_artifact_from_run_info() {
  local run_info="$1"
  local artifact_name="$2"
  
  if [ "$artifact_name" = "extension" ]; then
    install_extension_from_run_info "$run_info"
  elif [ "$artifact_name" = "binary" ]; then
    install_binary_from_run_info "$run_info"
  else
    echo "Invalid artifact name: $artifact_name"
    exit 1
  fi
}

function install_latest_nightly_artifact() {
  local artifact_name="$1"
  local run_info=$(get_latest_nightly_run_info)
  
  install_artifact_from_run_info "$run_info" "$artifact_name"
}

function install_latest_stable_artifact() {
  local artifact_name="$1"
  
  echo "Checking for latest (pre)release..."
  echo ""
  
  local release_json=$(curl -s "$RELEASE_URL")
  local tag=$(echo "$release_json" | jq -r '.[0].tag_name')
  local updated_at=$(echo "$release_json" | jq -r '.[0].published_at')
  local url=$(echo "$release_json" | jq -r '.[0].html_url')
  
  # UTC to system time
  if [ "$(uname)" == "Darwin" ]; then
    updated_at=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" "+%Y-%m-%d %H:%M:%S")
  else
    updated_at=$(date -d "$updated_at" "+%Y-%m-%d %H:%M:%S")
  fi
  
  if [ "$artifact_name" = "extension" ]; then
    local download_url="https://github.com/Myriad-Dreamin/tinymist/releases/download/$tag/$FILENAME"
    local file_path="$DOWNLOAD_DIR/$FILENAME"
    
    echo "Title: $tag"
    echo "Release Date: $updated_at"
    echo "For more information, visit: $url"
    echo ""
    echo "Downloading $FILENAME from $download_url"
    echo ""
    
    curl -sL -o "$file_path" "$download_url"
    if [ $? -ne 0 ]; then
      echo "File download failed: $download_url"
      exit 1
    fi
    
    install_extension "$file_path"
    rm -f "$file_path"
  elif [ "$artifact_name" = "binary" ]; then
    if [ "$UNAME" = "darwin" ]; then
      BINARY_NAME="tinymist"
    else
      BINARY_NAME="tinymist"
    fi
    
    local download_url="https://github.com/Myriad-Dreamin/tinymist/releases/download/$tag/$BINARY_FILENAME"
    local file_path="$DOWNLOAD_DIR/$BINARY_FILENAME"
    
    echo "Title: $tag"
    echo "Release Date: $updated_at"
    echo "For more information, visit: $url"
    echo ""
    echo "Downloading $BINARY_FILENAME from $download_url"
    echo ""
    
    curl -sL -o "$file_path" "$download_url"
    if [ $? -ne 0 ]; then
      echo "File download failed: $download_url"
      exit 1
    fi
    
    install_binary "$file_path" "$BINARY_NAME"
    rm -f "$file_path"
  else
    echo "Invalid artifact name: $artifact_name"
    exit 1
  fi
}

function install_artifact_by_run_id() {
  local run_id="$1"
  local artifact_name="$2"
  local info_url="https://api.github.com/repos/myriad-dreamin/tinymist/actions/runs/$run_id"
  
  local run_json=$(curl -s "$info_url")
  
  if [ "$(echo "$run_json" | jq -e '.message')" != "null" ]; then
    echo "Failed to fetch run info: $(echo "$run_json" | jq -r '.message')"
    exit 1
  fi
  
  local run_info=$(get_run_info "$run_json")
  install_artifact_from_run_info "$run_info" "$artifact_name"
}

function install_artifact_by_pr_number() {
  local pr_number="$1"
  local artifact_name="$2"
  local pr_info_url="https://api.github.com/repos/myriad-dreamin/tinymist/pulls/$pr_number"
  
  local pr_json=$(curl -s "$pr_info_url")
  
  if [ "$(echo "$pr_json" | jq -e '.message')" != "null" ]; then
    echo "Failed to fetch PR info: $(echo "$pr_json" | jq -r '.message')"
    exit 1
  fi
  
  local pr_head_sha=$(echo "$pr_json" | jq -r '.head.sha')
  local sha_runs_url="https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&head_sha=$pr_head_sha&status=success"
  
  local pr_runs_json=$(curl -s "$sha_runs_url")
  
  if [ "$(echo "$pr_runs_json" | jq -r '.total_count')" = "0" ]; then
    echo "No successful workflow runs found for PR $pr_number"
    exit 1
  fi
  
  local run_info=$(get_run_info "$(echo "$pr_runs_json" | jq -r '.workflow_runs[0]')")
  local pr_title=$(echo "$pr_json" | jq -r '.title')
  
  # Add PR info to run_info
  run_info=$(echo "$run_info" | jq --arg title "PR #$pr_number $pr_title - $(echo "$run_info" | jq -r '.display_title')" --arg pr_url "$(echo "$pr_json" | jq -r '.html_url')" '.display_title = $title | .pr_url = $pr_url')
  
  install_artifact_from_run_info "$run_info" "$artifact_name"
}

# Main logic
if [ "$BUILD_TYPE" = "--stable" ]; then
  install_latest_stable_artifact "$ARTIFACT_NAME"
elif [ "$BUILD_TYPE" = "--nightly" ]; then
  install_latest_nightly_artifact "$ARTIFACT_NAME"
elif [ "$BUILD_TYPE" = "--run" ] && [ -n "$RUN_ID" ]; then
  install_artifact_by_run_id "$RUN_ID" "$ARTIFACT_NAME"
elif [ "$BUILD_TYPE" = "--pr" ] && [ -n "$PR_NUMBER" ]; then
  install_artifact_by_pr_number "$PR_NUMBER" "$ARTIFACT_NAME"
else
  print_help
  exit 1
fi