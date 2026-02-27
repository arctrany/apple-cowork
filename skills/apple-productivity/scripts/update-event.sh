#!/bin/bash
# update-event.sh - 更新日历事件

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
NEW_TITLE=""
NEW_START=""
NEW_END=""
NEW_LOCATION=""
NEW_NOTE=""

usage() {
    echo "用法：$0 --title \"事件标题\" [更新选项]"
    echo ""
    echo "选项:"
    echo "  --title, -t       事件标题（必需）"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，帮助查找事件）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --new-title       新事件标题"
    echo "  --new-start       新开始时间（格式：YYYY-MM-DD HH:MM）"
    echo "  --new-end         新结束时间（格式：YYYY-MM-DD HH:MM）"
    echo "  --new-location    新地点"
    echo "  --new-note        新备注"
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
        --new-title)
            NEW_TITLE="$2"
            shift 2
            ;;
        --new-start)
            NEW_START="$2"
            shift 2
            ;;
        --new-end)
            NEW_END="$2"
            shift 2
            ;;
        --new-location)
            NEW_LOCATION="$2"
            shift 2
            ;;
        --new-note)
            NEW_NOTE="$2"
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

# 验证必需参数
if [ -z "$EVENT_TITLE" ]; then
    echo "错误：必须指定 --title 参数"
    usage
fi

# 验证至少有一个更新项
if [ -z "$NEW_TITLE" ] && [ -z "$NEW_START" ] && [ -z "$NEW_END" ] && [ -z "$NEW_LOCATION" ] && [ -z "$NEW_NOTE" ]; then
    echo "错误：必须指定至少一个更新选项"
    usage
fi

# 转义特殊字符
ESCAPED_TITLE="${EVENT_TITLE//\"/\\\"}"
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"
ESCAPED_NEW_TITLE="${NEW_TITLE//\"/\\\"}"
ESCAPED_NEW_LOCATION="${NEW_LOCATION//\"/\\\"}"
ESCAPED_NEW_NOTE="${NEW_NOTE//\"/\\\"}"

# 构建 AppleScript 更新语句
UPDATE_STATEMENTS=""

if [ -n "$NEW_TITLE" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set summary of targetEvent to \"$ESCAPED_NEW_TITLE\""
fi

if [ -n "$NEW_START" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set start date of targetEvent to date \"$NEW_START\""
fi

if [ -n "$NEW_END" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set end date of targetEvent to date \"$NEW_END\""
fi

if [ -n "$NEW_LOCATION" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set location of targetEvent to \"$ESCAPED_NEW_LOCATION\""
fi

if [ -n "$NEW_NOTE" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set note of targetEvent to \"$ESCAPED_NEW_NOTE\""
fi

# 创建 AppleScript
if [ -n "$DATE" ]; then
    APPLESCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set searchDate to date "$DATE 00:00:00"
        set nextDay to searchDate + 24 * 60 * 60

        set targetEvent to first event of targetCalendar whose summary = "$ESCAPED_TITLE" and start date ≥ searchDate and start date < nextDay
        $UPDATE_STATEMENTS
        return "更新成功"
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
        $UPDATE_STATEMENTS
        return "更新成功"
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

echo "✅ 成功更新事件：$EVENT_TITLE"
[ -n "$NEW_TITLE" ] && echo "   新标题：$NEW_TITLE"
[ -n "$NEW_START" ] && echo "   新开始：$NEW_START"
[ -n "$NEW_END" ] && echo "   新结束：$NEW_END"
[ -n "$NEW_LOCATION" ] && echo "   新地点：$NEW_LOCATION"
[ -n "$NEW_NOTE" ] && echo "   新备注：$NEW_NOTE"
