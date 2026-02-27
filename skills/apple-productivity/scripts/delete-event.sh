#!/bin/bash
# delete-event.sh - 删除日历事件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//' | tr -d '"' || echo "日历")
fi

# 参数解析
EVENT_TITLE=""
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DATE=""
CONFIRM=false

usage() {
    echo "用法：$0 --title \"事件标题\" [选项]"
    echo ""
    echo "选项:"
    echo "  --title, -t       事件标题（必需）"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，帮助查找事件）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --confirm, -y     确认删除（不需提示）"
    echo "  --help, -h        显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --title|-t)
            EVENT_TITLE="$2"
            shift 2
            ;;
        --date|-d)
            DATE="$2"
            shift 2
            ;;
        --calendar|-c)
            CALENDAR_NAME="$2"
            shift 2
            ;;
        --account|-a)
            ACCOUNT="$2"
            shift 2
            ;;
        --confirm|-y)
            CONFIRM=true
            shift
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

# 验证必需参数
if [ -z "$EVENT_TITLE" ]; then
    echo "错误：必须指定 --title 参数"
    usage
fi

# 确认删除
if [ "$CONFIRM" = false ]; then
    echo -n "⚠️  确定要删除事件 '$EVENT_TITLE' 吗？[y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "已取消删除"
        exit 0
    fi
fi

# 转义特殊字符
ESCAPED_TITLE="${EVENT_TITLE//\"/\\\"}"
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
if [ -n "$DATE" ]; then
    APPLESCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set searchDate to date "$DATE 00:00:00"
        set nextDay to searchDate + 24 * 60 * 60

        set targetEvent to first event of targetCalendar whose summary = "$ESCAPED_TITLE" and start date ≥ searchDate and start date < nextDay
        delete targetEvent
        return "删除成功"
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)
else
    APPLESCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set targetEvent to first event of targetCalendar whose summary = "$ESCAPED_TITLE"
        delete targetEvent
        return "删除成功"
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)
fi

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

if [[ "$RESULT" == *"错误："* ]]; then
    echo "❌ $RESULT"
    exit 1
fi

echo "✅ 已成功删除事件：$EVENT_TITLE"
