#!/bin/bash
# List all notes in a specified folder/account
# Usage: list-notes.sh [--account "账户名"] [--folder "文件夹名"]

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

# Execute AppleScript
osascript <<EOF
tell application "Notes"
    set accountName to "$ACCOUNT"
    set folderName to "$FOLDER"

    try
        set noteList to name of every note of folder folderName of account accountName
        if (count of noteList) is 0 then
            log "No notes found in folder '" & folderName & "'"
        else
            repeat with noteName in noteList
                log noteName
            end repeat
        end if
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF
