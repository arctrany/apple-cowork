#!/bin/bash
# list-events.sh - 列出日历事件

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
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DATE=""
RANGE="day"  # day, week, month

usage() {
    echo "用法：$0 [选项]"
    echo ""
    echo "选项:"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，默认：今天）"
    echo "  --range, -r       范围（day/week/month，默认：day）"
    echo "  --help, -h        显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --calendar|-c)
            CALENDAR_NAME="$2"
            shift 2
            ;;
        --account|-a)
            ACCOUNT="$2"
            shift 2
            ;;
        --date|-d)
            DATE="$2"
            shift 2
            ;;
        --range|-r)
            RANGE="$2"
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

# 设置日期范围
if [ -z "$DATE" ]; then
    DATE=$(date +"%Y-%m-%d")
fi

case $RANGE in
    day)
        START_DATE="${DATE} 00:00:00"
        END_DATE="${DATE} 23:59:59"
        ;;
    week)
        # 计算周一
        DAY_OF_WEEK=$(date -j -f "%Y-%m-%d" "$DATE" +"%u")
        MONDAY_OFFSET=$((DAY_OF_WEEK - 1))
        MONDAY=$(date -v-${MONDAY_OFFSET}d -j -f "%Y-%m-%d" "$DATE" +"%Y-%m-%d")
        SUNDAY=$(date -v+6d -j -f "%Y-%m-%d" "$MONDAY" +"%Y-%m-%d")
        START_DATE="${MONDAY} 00:00:00"
        END_DATE="${SUNDAY} 23:59:59"
        ;;
    month)
        # 计算月初和月末
        START_DATE=$(date -j -f "%Y-%m-%d" "$DATE" +"%Y-%m-01")" 00:00:00"
        END_DATE=$(date -v+1m -j -f "%Y-%m-01" "$DATE" +"%Y-%m-01")" 23:59:59"
        END_DATE=$(date -v-1d -j -f "%Y-%m-%d %H:%M:%S" "$END_DATE" +"%Y-%m-%d")" 23:59:59"
        ;;
esac

# 转义特殊字符
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
APPLESCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set startDate to date "$START_DATE"
        set endDate to date "$END_DATE"

        set filteredEvents to every event of targetCalendar whose (start date ≥ startDate and start date ≤ endDate)

        if (count of filteredEvents) is 0 then
            log "该时间段没有事件"
        else
            repeat with e in filteredEvents
                set eventDate to start date of e
                set eventTime to text -11 thru -6 of (eventDate as string)
                set eventSummary to summary of e

                set locationText to ""
                if location of e is not "" then
                    set locationText to " @" & (location of e)
                end if

                log eventTime & " " & eventSummary & locationText
            end repeat
        end if

        return count of filteredEvents
    end try
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)
COUNT=$(echo "$RESULT" | tail -1)

echo ""
echo "=== $CALENDAR_NAME ($RANGE: $DATE) ==="
echo "$RESULT" | head -n -1
echo ""
echo "共 $COUNT 个事件"
