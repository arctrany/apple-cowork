#!/bin/bash
# Create folder hierarchy in Apple Notes
# Supports nested folders with path-like syntax
#
# Usage:
#   create-folder.sh "文件夹名" [--account "iCloud"]
#   create-folder.sh "技术文档/Apple 生态" [--account "iCloud"]
#   create-folder.sh "项目/apple-cowork/文档" -account "On My Mac"

set -e

FOLDER_PATH=""
ACCOUNT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --account) ACCOUNT="$2"; shift 2 ;;
        *)
            if [[ -z "$FOLDER_PATH" ]]; then
                FOLDER_PATH="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$FOLDER_PATH" ]]; then
    echo "Error: Folder path is required"
    echo "Usage: create-folder.sh \"路径/到/文件夹\" [--account \"iCloud\"]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"
if [[ -f "$CONFIG_FILE" && -z "$ACCOUNT" ]]; then
    ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | sed 's/[[:space:]]*#.*$//')
fi
ACCOUNT=${ACCOUNT:-"iCloud"}

# Split folder path into parts
IFS='/' read -ra FOLDER_PARTS <<< "$FOLDER_PATH"

osascript <<EOF
tell application "Notes"
    set accountName to "$ACCOUNT"
    set folderParts to {"$(IFS='/'; echo "${FOLDER_PARTS[*]}")"}
    set currentFolder to account accountName

    repeat with part in folderParts
        set partName to part
        if partName is not "" then
            try
                set existingFolder to folder partName of currentFolder
                set currentFolder to existingFolder
                log "Folder exists: " & partName
            on error
                set newFolder to make new folder at currentFolder with properties {name: partName}
                set currentFolder to newFolder
                log "Folder created: " & partName
            end try
        end if
    end repeat

    log "Folder hierarchy ready: $(echo "$FOLDER_PATH" | sed 's|/| > |g')"
end tell
EOF

echo "✓ 文件夹已创建：$FOLDER_PATH"
