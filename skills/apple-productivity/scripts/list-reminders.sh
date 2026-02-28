#!/bin/bash
# list-reminders.sh - 列出提醒事项

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_LIST="提醒事项"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_LIST=$(grep "^default_reminder_list:" "$CONFIG_FILE" | sed 's/default_reminder_list: *//' | tr -d '"' || echo "提醒事项")
fi

# 参数解析
REMINDER_LIST="$DEFAULT_LIST"
ACCOUNT="$DEFAULT_ACCOUNT"
STATUS="all"  # all, pending, completed

usage() {
    echo "用法：$0 [选项]"
    echo ""
    echo "选项:"
    echo "  --list, -l        列表名称（默认：$DEFAULT_LIST）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --status, -s      状态过滤（all/pending/completed，默认：all）"
    echo "  --help, -h        显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --list|-l)
            REMINDER_LIST="$2"
            shift 2
            ;;
        --account|-a)
            ACCOUNT="$2"
            shift 2
            ;;
        --status|-s)
            STATUS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "未知选项：$1"
            usage
            ;;
    esac
done

# 转义特殊字符
ESCAPED_LIST="${REMINDER_LIST//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 构建 AppleScript
case $STATUS in
    pending)
        FILTER_CONDITION="whose completed is false"
        ;;
    completed)
        FILTER_CONDITION="whose completed is true"
        ;;
    *)
        FILTER_CONDITION=""
        ;;
esac

APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    set targetList to list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
    set remindersToShow to every reminder of targetList $FILTER_CONDITION

    if (count of remindersToShow) is 0 then
        log "没有符合条件的提醒事项"
    else
        repeat with r in remindersToShow
            set statusIcon to "○"
            if completed of r then set statusIcon to "●"

            set priorityText to ""
            if priority of r is 1 then set priorityText to "[低]"
            if priority of r is 2 then set priorityText to "[中]"
            if priority of r is 3 then set priorityText to "[高]"

            set dueText to ""
            if due date of r is not missing value then
                set dueText to " (截止：" & (due date of r) & ")"
            end if

            log statusIcon & " " & name of r & priorityText & dueText
        end repeat
    end if

    return count of remindersToShow
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

# 分离输出和计数
OUTPUT_LINES=$(echo "$RESULT" | grep -v "^$")
COUNT=$(echo "$RESULT" | tail -1)

echo ""
echo "=== $REMINDER_LIST ($STATUS) ==="
if [ -n "$OUTPUT_LINES" ]; then
    echo "$OUTPUT_LINES" | head -n -1 2>/dev/null || echo "$OUTPUT_LINES"
fi
echo ""
echo "共 $COUNT 个任务"
