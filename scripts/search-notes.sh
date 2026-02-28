#!/bin/bash
# Search notes by keyword
# Usage: search-notes.sh --query "关键词" [--account "账户名"]

set -e

# Default values
QUERY=""
ACCOUNT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --query)
            QUERY="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$QUERY" ]]; then
    echo "Error: --query is required"
    exit 1
fi

# Load configuration from .local.md if exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../skills/apple-notes/.local.md"
if [[ -f "$CONFIG_FILE" ]]; then
    if [[ -z "$ACCOUNT" ]]; then
        ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//')
    fi
fi

# Set defaults if not configured
ACCOUNT=${ACCOUNT:-"iCloud"}

# Write query to temp file to avoid encoding issues with Chinese/special characters
TEMP_FILE=$(mktemp /tmp/apple_notes_query.XXXXXX)
printf '%s' "$QUERY" > "$TEMP_FILE"

# Execute AppleScript
osascript <<EOF
tell application "Notes"
    set accountName to "$ACCOUNT"
    set searchQuery to do shell script "cat '$TEMP_FILE'"

    try
        set foundNotes to search for searchQuery in account accountName
        if (count of foundNotes) is 0 then
            log "No notes found matching query: " & searchQuery
        else
            repeat with foundNote in foundNotes
                log (name of foundNote)
            end repeat
        end if
    on error errMsg
        log "Error: " & errMsg
        error 1
    end try
end tell
EOF

rm -f "$TEMP_FILE"
