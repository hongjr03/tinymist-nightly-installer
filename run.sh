#!/bin/bash

if [ "$1" != "" ] && [ "$1" != "--stable" ] && [ "$1" != "--nightly" ]; then
  echo "Usage: $0 [--stable|--nightly]"
  echo "Defaulting to nightly build without arguments."
  echo ""
  echo " --stable: Install the latest stable release"
  echo " --nightly: Install the latest nightly build"
  echo ""
  echo "Example: $0 --stable"
  echo ""
  exit 1
fi

DOWNLOAD_DIR="/tmp"

UNAME=$(uname | tr '[:upper:]' '[:lower:]')
UNAME_M=$(uname -m | tr '[:upper:]' '[:lower:]')

echo "Your system is $UNAME-$UNAME_M"

FILENAME="tinymist-$UNAME-$UNAME_M.vsix"
ZIPFILE="$DOWNLOAD_DIR/$FILENAME.zip"
NIGHTLY_DOWNLOAD_URL="https://nightly.link/Myriad-Dreamin/tinymist/workflows/release-vscode/main/$FILENAME.zip"
RELEASE_DOWNLOAD_URL="https://github.com/Myriad-Dreamin/tinymist/releases/latest/download/$FILENAME"
NIGHTLY_URL="https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
RELEASE_URL="https://api.github.com/repos/myriad-dreamin/tinymist/releases/latest"


if [ "$1" == "--stable" ]; then
  echo "Checking for latest stable release..."
  echo ""
  DOWNLOAD_URL=$RELEASE_DOWNLOAD_URL
  INFO_URL=$RELEASE_URL
  DISPLAY_TITLE=$(curl -s "$INFO_URL" | jq -r '.tag_name')
  UPDATED_AT=$(curl -s "$INFO_URL" | jq -r '.published_at')
  URL=$( curl -s "$INFO_URL" | jq -r '.html_url' )

  # don't need a zip file for stable releases
  ZIPFILE="$DOWNLOAD_DIR/$FILENAME"
else
  echo "Checking for latest nightly build..."
  echo ""
  DOWNLOAD_URL=$NIGHTLY_DOWNLOAD_URL
  INFO_URL=$NIGHTLY_URL
  DISPLAY_TITLE=$(curl -s "$INFO_URL" | jq -r '.workflow_runs[0].display_title')
  UPDATED_AT=$(curl -s "$INFO_URL" | jq -r '.workflow_runs[0].updated_at')
  URL=$( curl -s "$INFO_URL" | jq -r '.workflow_runs[0].html_url' )
fi

echo "$DISPLAY_TITLE"
echo "Build Time (UTC): $UPDATED_AT"
echo "For more information, visit: $URL"
echo ""
echo "Downloading $FILENAME from $DOWNLOAD_URL"
echo ""
curl -sL -o "$ZIPFILE" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
  echo "File download failed: $DOWNLOAD_URL"
  exit 1
fi

if [ "$1" != "--stable" ]; then
  unzip -qq "$ZIPFILE" -d "$DOWNLOAD_DIR"
  if [ $? -ne 0 ]; then
    echo "Failed to unzip file: $ZIPFILE"
    exit 1
  fi

  echo "File downloaded and unzipped to $DOWNLOAD_DIR/$FILENAME"
fi

code --install-extension "$DOWNLOAD_DIR/$FILENAME"

if [ $? -eq 0 ]; then
  echo "VS Code extension installed successfully: $FILENAME"
  echo "Please reload VS Code to activate the extension"
else
  echo "VS Code extension installation failed"
fi

rm -f "$ZIPFILE" "$DOWNLOAD_DIR/$FILENAME"
