#!/bin/bash
# Get the full content of a specific note
# Usage: get-note.sh --name "笔记名称" [--account "账户名"] [--folder "文件夹名"]

set -e

# Default values
NOTE_NAME=""
ACCOUNT=""
FOLDER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NOTE_NAME="$2"
            shift 2
            ;;
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

# Validate required arguments
if [[ -z "$NOTE_NAME" ]]; then
    echo "Error: --name is required"
    exit 1
fi

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

# Execute AppleScript using 'first note whose name is' pattern
osascript <<EOF
tell application "Notes"
    set accountName to "$ACCOUNT"
    set folderName to "$FOLDER"
    set noteName to "$NOTE_NAME"

    try
        set targetNote to first note of folder folderName of account accountName whose name is noteName
        set noteBody to body of targetNote
        log noteBody
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF
