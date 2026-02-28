#!/bin/bash
# Create or update an Apple Note with Tech Writer style (Notion/Obsidian-inspired)
# Supports: frontmatter properties, STAR framework, callout blocks, checkboxes
#
# Usage:
#   note-with-style.sh --name "笔记名称" --file "input.md" [--folder "文件夹"] [--update]
#   echo "# Markdown" | note-with-style.sh --name "笔记名称" [--folder "文件夹"]
#
# ## Supported syntax:
#
# Frontmatter (properties grid):
#   ---
#   状态：进行中
#   负责人：张三
#   ---
#
# STAR framework:
#   ::: star
#   Situation: xxx
#   Task: xxx
#   Action: xxx
#   Result: xxx
#   :::
#
# Callout blocks:
#   > [!NOTE] 注记内容
#   > [!WARNING] 警告内容
#   > [!TIP] 提示内容
#   > [!KEY] 核心洞察
#   > [!TODO] 待办事项
#   > [!SUCCESS] 成功经验
#   > [!ERROR] 错误信息
#   > [!QUESTION] 问题
#
# Checkboxes:
#   - [ ] 未完成任务
#   - [x] 已完成任务

set -e

NOTE_NAME=""
NOTE_FILE=""
NOTE_BODY=""
FOLDER=""
TAGS=""
STATUS=""
OWNER=""
MODULE=""
DEADLINE=""
UPDATE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD_CONVERTER="$SCRIPT_DIR/md-to-notes-html.py"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)     NOTE_NAME="$2"; shift 2 ;;
        --file)     NOTE_FILE="$2"; shift 2 ;;
        --body)     NOTE_BODY="$2"; shift 2 ;;
        --folder)   FOLDER="$2";    shift 2 ;;
        --tags)     TAGS="$2";      shift 2 ;;
        --status)   STATUS="$2";    shift 2 ;;
        --owner)    OWNER="$2";     shift 2 ;;
        --module)   MODULE="$2";    shift 2 ;;
        --deadline) DEADLINE="$2";  shift 2 ;;
        --update)   UPDATE=true;    shift   ;;
        *)          echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$NOTE_NAME" ]]; then
    echo "Error: --name is required"
    exit 1
fi

# Read from file or body
if [[ -n "$NOTE_FILE" ]]; then
    if [[ ! -f "$NOTE_FILE" ]]; then
        echo "Error: File not found: $NOTE_FILE"
        exit 1
    fi
    NOTE_BODY=$(cat "$NOTE_FILE")
elif [[ -z "$NOTE_BODY" ]]; then
    # Read from stdin
    NOTE_BODY=$(cat)
fi

if [[ -z "$NOTE_BODY" ]]; then
    echo "Error: --body or --file is required (or pipe input)"
    exit 1
fi

# Build frontmatter from parameters
FRONTMATTER=""
if [[ -n "$TAGS" || -n "$STATUS" || -n "$OWNER" || -n "$MODULE" || -n "$DEADLINE" ]]; then
    FRONTMATTER="---\n"
    if [[ -n "$TAGS" ]]; then
        # Convert comma-separated tags to array format
        TAGS_ARRAY=$(echo "$TAGS" | sed 's/,/", "/g')
        FRONTMATTER="${FRONTMATTER}标签：[\"${TAGS_ARRAY}\"]\n"
    fi
    if [[ -n "$STATUS" ]]; then
        FRONTMATTER="${FRONTMATTER}状态：${STATUS}\n"
    fi
    if [[ -n "$OWNER" ]]; then
        FRONTMATTER="${FRONTMATTER}负责人：${OWNER}\n"
    fi
    if [[ -n "$MODULE" ]]; then
        FRONTMATTER="${FRONTMATTER}模块：${MODULE}\n"
    fi
    if [[ -n "$DEADLINE" ]]; then
        FRONTMATTER="${FRONTMATTER}截止：${DEADLINE}\n"
    fi
    FRONTMATTER="${FRONTMATTER}---\n\n"
fi

# Prepend frontmatter to body if provided via parameters
if [[ -n "$FRONTMATTER" ]]; then
    # Check if body already has frontmatter
    if [[ "$NOTE_BODY" == "---"* ]]; then
        echo "Warning: Body already contains frontmatter, parameter-based frontmatter will be skipped"
    else
        NOTE_BODY=$(echo -e "${FRONTMATTER}${NOTE_BODY}")
    fi
fi

# Load config
CONFIG_FILE="$SCRIPT_DIR/../.local.md"
if [[ -f "$CONFIG_FILE" && -z "$FOLDER" ]]; then
    FOLDER=$(grep "^default_folder:" "$CONFIG_FILE" | sed 's/default_folder: *//')
fi
FOLDER=${FOLDER:-"Notes"}

# Convert Markdown → Apple Notes HTML
HTML_TEMP=$(mktemp /tmp/apple_notes_html.XXXXXX)
printf '%s' "$NOTE_BODY" | python3 "$MD_CONVERTER" > "$HTML_TEMP"

osascript <<EOF
tell application "Notes"
    set folderName to "$FOLDER"
    set noteName to "$NOTE_NAME"
    set noteBody to do shell script "cat '$HTML_TEMP'"

    try
        set existingNote to note noteName of folder folderName
        if $UPDATE then
            set body of existingNote to noteBody
            log "Note updated: " & (name of existingNote)
        else
            -- Create new note with unique name
            set timestamp to do shell script "date +%Y%m%d_%H%M%S"
            set newName to noteName & " " & timestamp
            set newNote to make new note at folder folderName with properties {name: newName, body: noteBody}
            log "Note created: " & (name of newNote)
        end if
    on error errMsg
        log "Error: " & errMsg
        if $UPDATE then
            error 1
        else
            -- Try creating with unique name
            set timestamp to do shell script "date +%Y%m%d_%H%M%S"
            set newName to noteName & " " & timestamp
            set newNote to make new note at folder folderName with properties {name: newName, body: noteBody}
            log "Note created: " & (name of newNote)
        end if
    end try
end tell
EOF

rm -f "$HTML_TEMP"
echo "done"
