#!/bin/bash
# Create or update an Apple Note from Markdown content
# Usage: note-from-markdown.sh --name "笔记名称" --body "# Markdown 内容" [--folder "文件夹"] [--update]

set -e

NOTE_NAME=""
NOTE_BODY=""
FOLDER=""
UPDATE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD_CONVERTER="$SCRIPT_DIR/md-to-notes-html.py"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)   NOTE_NAME="$2"; shift 2 ;;
        --body)   NOTE_BODY="$2"; shift 2 ;;
        --folder) FOLDER="$2";    shift 2 ;;
        --update) UPDATE=true;    shift   ;;
        *)        echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$NOTE_NAME" ]]; then echo "Error: --name is required"; exit 1; fi
if [[ -z "$NOTE_BODY" ]]; then echo "Error: --body is required"; exit 1; fi

# Load config
CONFIG_FILE="$SCRIPT_DIR/../.local.md"
if [[ -f "$CONFIG_FILE" && -z "$FOLDER" ]]; then
    FOLDER=$(grep "^default_folder:" "$CONFIG_FILE" | sed 's/default_folder: *//')
fi
FOLDER=${FOLDER:-"Notes"}

# Convert Markdown → Apple Notes HTML
MD_TEMP=$(mktemp /tmp/apple_notes_md.XXXXXX)
HTML_TEMP=$(mktemp /tmp/apple_notes_html.XXXXXX)
printf '%s' "$NOTE_BODY" > "$MD_TEMP"
python3 "$MD_CONVERTER" < "$MD_TEMP" > "$HTML_TEMP"

if $UPDATE; then
    # Update existing note
    osascript <<EOF
tell application "Notes"
    set folderName to "$FOLDER"
    set noteName to "$NOTE_NAME"
    set noteBody to do shell script "cat '$HTML_TEMP'"
    try
        set existingNote to note noteName of folder folderName
        set body of existingNote to noteBody
        log "Note updated: " & (name of existingNote)
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF
else
    # Create new note
    osascript <<EOF
tell application "Notes"
    set folderName to "$FOLDER"
    set noteName to "$NOTE_NAME"
    set noteBody to do shell script "cat '$HTML_TEMP'"
    try
        set newNote to make new note at folder folderName with properties {name: noteName, body: noteBody}
        log "Note created: " & (name of newNote)
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF
fi

rm -f "$MD_TEMP" "$HTML_TEMP"
