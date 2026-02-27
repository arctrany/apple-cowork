#!/bin/bash
# Create a new note
# Usage: create-note.sh --name "笔记名称" --body "笔记内容" [--folder "文件夹名"]

set -e

# Default values
NOTE_NAME=""
NOTE_BODY=""
FOLDER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NOTE_NAME="$2"
            shift 2
            ;;
        --body)
            NOTE_BODY="$2"
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

if [[ -z "$NOTE_BODY" ]]; then
    echo "Error: --body is required"
    exit 1
fi

# Load configuration from .local.md if exists
CONFIG_FILE="$HOME/.claude/plugins/cache/claude-plugins-official/apple-notes/.local.md"
if [[ -f "$CONFIG_FILE" ]]; then
    if [[ -z "$FOLDER" ]]; then
        FOLDER=$(grep "^default_folder:" "$CONFIG_FILE" | sed 's/default_folder: *//')
    fi
fi

# Set defaults if not configured
FOLDER=${FOLDER:-"Notes"}

# Write body to temp file to avoid encoding issues with Chinese/special characters
TEMP_FILE=$(mktemp /tmp/apple_notes_body.XXXXXX)
printf '%s' "$NOTE_BODY" > "$TEMP_FILE"

# Execute AppleScript
osascript <<EOF
tell application "Notes"
    set folderName to "$FOLDER"
    set noteName to "$NOTE_NAME"
    set noteBody to do shell script "cat '$TEMP_FILE'"

    try
        set newNote to make new note at folder folderName with properties {name: noteName, body: noteBody}
        log "Note created successfully: " & (name of newNote)
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF

rm -f "$TEMP_FILE"
