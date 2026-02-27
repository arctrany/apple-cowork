#!/bin/bash
# Update the notes index in Apple Notes
# Scans a directory for markdown files and generates an index note
#
# Usage:
#   update-index.sh [--scan-dir "~/Documents/Notes"] [--output "笔记索引"] [--folder "Notes"]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_DIR=~/Documents/Notes
OUTPUT="笔记索引"
FOLDER="Notes"

while [[ $# -gt 0 ]]; do
    case $1 in
        --scan-dir) SCAN_DIR="$2"; shift 2 ;;
        --output)   OUTPUT="$2";   shift 2 ;;
        --folder)   FOLDER="$2";   shift 2 ;;
        *)          echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "📖 扫描笔记目录：$SCAN_DIR"
echo "📝 索引笔记名称：$OUTPUT"
echo "📁 目标文件夹：$FOLDER"
echo ""

python3 "$SCRIPT_DIR/index-generator.py" \
    --scan-dir "$SCAN_DIR" \
    --output "$OUTPUT" \
    --folder "$FOLDER"
