#!/bin/bash
# Get all notes with their full content
# Usage: get-all-notes.sh [--account "账户名"] [--folder "文件夹名"]

set -e

# Default values
ACCOUNT=""
FOLDER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --folder)
            FOLDER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Load configuration from .local.md if exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../skills/apple-notes/.local.md"
if [[ -f "$CONFIG_FILE" ]]; then
    if [[ -z "$ACCOUNT" ]]; then
        ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//')
    fi
    if [[ -z "$FOLDER" ]]; then
        FOLDER=$(grep "^default_folder:" "$CONFIG_FILE" | sed 's/default_folder: *//')
    fi
fi

# Set defaults if not configured
ACCOUNT=${ACCOUNT:-"iCloud"}
FOLDER=${FOLDER:-"Notes"}

# Execute AppleScript to get all notes with content
osascript <<EOF
tell application "Notes"
    set accountName to "$ACCOUNT"
    set folderName to "$FOLDER"

    try
        set noteList to every note of folder folderName of account accountName
        repeat with n in noteList
            log "========================================"
            log "TITLE: " & name of n
            log "ID: " & id of n
            log "BODY: " & body of n
            log "----------------------------------------"
        end repeat
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF
