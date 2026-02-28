#!/bin/bash
# suggest-meeting-time.sh - 建议会议时间

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"
DEFAULT_DURATION=60
DEFAULT_RANGE="week"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//; s/ *#.*//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//; s/ *#.*//' | tr -d '"' || echo "日历")
fi

# 参数解析
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DURATION=$DEFAULT_DURATION
RANGE=$DEFAULT_RANGE
PARTICIPANTS=""
START_DATE=""

usage() {
    echo "用法：$0 [选项]"
    echo ""
    echo "选项:"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --duration        会议时长（分钟，默认：$DURATION）"
    echo "  --range           搜索范围（today/week/next-week，默认：$RANGE）"
    echo "  --participants    参与者列表（逗号分隔，未来功能）"
    echo "  --start-date      开始日期（格式：YYYY-MM-DD）"
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
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --range)
            RANGE="$2"
            shift 2
            ;;
        --participants)
            PARTICIPANTS="$2"
            shift 2
            ;;
        --start-date)
            START_DATE="$2"
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
if [ -z "$START_DATE" ]; then
    START_DATE=$(date +"%Y-%m-%d")
fi

case $RANGE in
    today)
        END_DATE="$START_DATE"
        ;;
    week)
        # 本周五
        DAY_OF_WEEK=$(date -j -f "%Y-%m-%d" "$START_DATE" +"%u")
        DAYS_TO_FRIDAY=$((5 - DAY_OF_WEEK))
        if [ $DAYS_TO_FRIDAY -lt 0 ]; then
            DAYS_TO_FRIDAY=$((DAYS_TO_FRIDAY + 7))
        fi
        END_DATE=$(date -v+${DAYS_TO_FRIDAY}d -j -f "%Y-%m-%d" "$START_DATE" +"%Y-%m-%d")
        ;;
    next-week)
        # 下周五
        NEXT_MONDAY=$(date -v+1w -j -f "%Y-%m-%d" "$START_DATE" +"%Y-%m-%d")
        DAY_OF_WEEK=$(date -j -f "%Y-%m-%d" "$NEXT_MONDAY" +"%u")
        DAYS_TO_FRIDAY=$((5 - DAY_OF_WEEK))
        if [ $DAYS_TO_FRIDAY -lt 0 ]; then
            DAYS_TO_FRIDAY=$((DAYS_TO_FRIDAY + 7))
        fi
        END_DATE=$(date -v+${DAYS_TO_FRIDAY}d -j -f "%Y-%m-%d" "$NEXT_MONDAY" +"%Y-%m-%d")
        START_DATE="$NEXT_MONDAY"
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
        set startDate to date "$START_DATE 00:00:00"
        set endDate to date "$END_DATE 23:59:59"

        -- 获取范围内所有事件
        set rangeEvents to every event of targetCalendar whose start date ≥ startDate and start date ≤ endDate

        -- 按日期分组查找空闲时间
        set suggestedTimes to {}
        set currentTime to startDate
        set oneDay to 24 * 60 * 60

        repeat while currentTime ≤ endDate
            -- 获取当天事件
            set dayStart to currentTime - (hours of currentTime) * 60 * 60 - (minutes of currentTime) * 60 - (seconds of currentTime) * 60
            set dayEnd to dayStart + oneDay

            set dayEvents to every event of targetCalendar whose start date ≥ dayStart and start date < dayEnd

            -- 按开始时间排序
            set workStart to dayStart + 9 * 60 * 60  -- 9:00 开始
            set workEnd to dayStart + 17 * 60 * 60   -- 17:00 结束

            repeat with e in dayEvents
                if start date of e > workStart and start date of e < workEnd then
                    if start date of e - workStart ≥ $DURATION * 60 then
                        set end of suggestedTimes to {date:workStart, duration:$DURATION}
                        set workStart to start date of e
                    else
                        set workStart to end date of e
                    end if
                end if
            end repeat

            -- 检查下班前
            if workEnd - workStart ≥ $DURATION * 60 then
                set end of suggestedTimes to {date:workStart, duration:$DURATION}
            end if

            set currentTime to currentTime + oneDay
        end repeat

        -- 返回结果
        if (count of suggestedTimes) is 0 then
            return "在指定范围内没有找到合适的会议时间"
        else
            set resultText to "推荐的会议时间（$DURATION 分钟）：" & linefeed
            set count to 0
            repeat with slot in suggestedTimes
                if count ≥ 5 then exit repeat  -- 最多显示 5 个建议
                set slotDate to date of slot
                set slotEnd to slotDate + (duration of slot) * 60
                set resultText to resultText & "  • " & (text 1 thru 10 of (slotDate as string)) & " " & (text -11 thru -6 of (slotDate as string)) & " - " & (text -11 thru -6 of (slotEnd as string)) & linefeed
                set count to count + 1
            end repeat
            return resultText
        end if
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

echo ""
echo "=== 会议时间建议 ==="
echo "日历：$CALENDAR_NAME"
echo "会议时长：$DURATION 分钟"
echo "搜索范围：$START_DATE 至 $END_DATE"
[ -n "$PARTICIPANTS" ] && echo "参与者：$PARTICIPANTS（注：多参与者功能待实现）"
echo ""
echo "$RESULT"
