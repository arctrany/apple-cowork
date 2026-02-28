#!/bin/bash
# get-event.sh - 获取单个事件的详细信息

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//; s/ *#.*//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//; s/ *#.*//' | tr -d '"' || echo "日历")
fi

# 参数解析
EVENT_TITLE=""
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DATE=""

usage() {
    echo "用法：$0 --title \"事件标题\" [选项]"
    echo ""
    echo "选项:"
    echo "  --title, -t       事件标题（必需）"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，帮助查找事件）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
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

        set info to "名称：" & summary of targetEvent & linefeed
        set info to info & "日历：" & (name of container of targetEvent) & linefeed
        set info to info & "开始：" & (start date of targetEvent) & linefeed
        set info to info & "结束：" & (end date of targetEvent) & linefeed

        if location of targetEvent is not "" then
            set info to info & "地点：" & (location of targetEvent) & linefeed
        end if

        if note of targetEvent is not "" then
            set info to info & "备注：" & (note of targetEvent) & linefeed
        end if

        if allday event of targetEvent then
            set info to info & "类型：全天事件" & linefeed
        else
            set info to info & "类型：定时事件" & linefeed
        end if

        set info to info & "ID：" & id of targetEvent

        return info
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

        set info to "名称：" & summary of targetEvent & linefeed
        set info to info & "日历：" & (name of container of targetEvent) & linefeed
        set info to info & "开始：" & (start date of targetEvent) & linefeed
        set info to info & "结束：" & (end date of targetEvent) & linefeed

        if location of targetEvent is not "" then
            set info to info & "地点：" & (location of targetEvent) & linefeed
        end if

        if note of targetEvent is not "" then
            set info to info & "备注：" & (note of targetEvent) & linefeed
        end if

        if allday event of targetEvent then
            set info to info & "类型：全天事件" & linefeed
        else
            set info to info & "类型：定时事件" & linefeed
        end if

        set info to info & "ID：" & id of targetEvent

        return info
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

echo "=== 事件详情 ==="
echo "$RESULT"
