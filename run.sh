#!/bin/bash

DOWNLOAD_DIR="/tmp"

UNAME=$(uname | tr '[:upper:]' '[:lower:]')
UNAME_M=$(uname -m | tr '[:upper:]' '[:lower:]')

FILENAME="tinymist-$UNAME-$UNAME_M.vsix"
ZIPFILE="$DOWNLOAD_DIR/$FILENAME.zip"
DOWNLOAD_URL="https://nightly.link/Myriad-Dreamin/tinymist/workflows/release-vscode/main/$FILENAME.zip"
NIGHTLY_URL="https://api.github.com/repos/myriad-dreamin/tinymist/actions/workflows/release-vscode.yml/runs?per_page=1&branch=main&event=push&status=success"
DISPLAY_TITLE=$(curl -s "$NIGHTLY_URL" | jq -r '.workflow_runs[0].display_title')
UPDATED_AT=$(curl -s "$NIGHTLY_URL" | jq -r '.workflow_runs[0].updated_at')

echo "Latest Build: $DISPLAY_TITLE"
echo "Build Time (UTC): $UPDATED_AT"

wget -q -O "$ZIPFILE" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
  echo "File download failed: $DOWNLOAD_URL"
  exit 1
fi

unzip -qq "$ZIPFILE" -d "$DOWNLOAD_DIR"
if [ $? -ne 0 ]; then
  echo "Failed to unzip file: $ZIPFILE"
  exit 1
fi

echo "File downloaded and unzipped to $DOWNLOAD_DIR/$FILENAME"

code --install-extension "$DOWNLOAD_DIR/$FILENAME"

if [ $? -eq 0 ]; then
  echo "VS Code extension installed successfully: $FILENAME"
  echo "Please reload VS Code to activate the extension"
  rm -f "$ZIPFILE" "$DOWNLOAD_DIR/$FILENAME"
else
  echo "VS Code extension installation failed"
fi
