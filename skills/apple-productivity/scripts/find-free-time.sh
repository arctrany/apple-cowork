#!/bin/bash
# find-free-time.sh - 查找空闲时间段

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"
DEFAULT_DURATION=60
DEFAULT_WORK_START=9
DEFAULT_WORK_END=18

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//' | tr -d '"' || echo "日历")
fi

# 参数解析
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DATE=""
DURATION=$DEFAULT_DURATION
WORK_START=$DEFAULT_WORK_START
WORK_END=$DEFAULT_WORK_END

usage() {
    echo "用法：$0 --date \"日期\" [选项]"
    echo ""
    echo "选项:"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，必需）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --duration        所需时长（分钟，默认：$DURATION）"
    echo "  --work-start      工作开始时间（小时，默认：$WORK_START）"
    echo "  --work-end        工作结束时间（小时，默认：$WORK_END）"
    echo "  --help, -h        显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
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
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --work-start)
            WORK_START="$2"
            shift 2
            ;;
        --work-end)
            WORK_END="$2"
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
if [ -z "$DATE" ]; then
    echo "错误：必须指定 --date 参数"
    usage
fi

# 转义特殊字符
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
APPLESCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set searchDate to date "$DATE 00:00:00"
        set nextDay to searchDate + 24 * 60 * 60

        -- 获取当天所有事件
        set dayEvents to every event of targetCalendar whose start date ≥ searchDate and start date < nextDay

        -- 按开始时间排序事件
        set sortedEvents to {}
        repeat with e in dayEvents
            set end of sortedEvents to e
        end repeat

        -- 查找空闲时间段
        set freeSlots to {}
        set currentTime to searchDate + $WORK_START * 60 * 60  -- 工作开始时间

        repeat with e in sortedEvents
            set eventStart to start date of e
            set eventEnd to end date of e

            -- 检查事件前是否有足够空闲时间
            if eventStart - currentTime ≥ $DURATION * 60 then
                set end of freeSlots to {start:currentTime, end:eventStart}
            end if

            -- 更新当前时间为事件结束时间
            if eventEnd > currentTime then set currentTime to eventEnd
        end repeat

        -- 检查下班前是否有足够空闲时间
        set workEndTime to searchDate + $WORK_END * 60 * 60
        if workEndTime - currentTime ≥ $DURATION * 60 then
            set end of freeSlots to {start:currentTime, end:workEndTime}
        end if

        -- 返回结果
        if (count of freeSlots) is 0 then
            return "没有找到合适的空闲时间"
        else
            set resultText to "可用的空闲时间段（≥ $DURATION 分钟）：" & linefeed
            repeat with slot in freeSlots
                set startTime to start of slot
                set endTime to end of slot
                set slotDuration to (endTime - startTime) div 60
                set resultText to resultText & "  • " & (text -11 thru -6 of (startTime as string)) & " - " & (text -11 thru -6 of (endTime as string)) & " (" & slotDuration & "分钟)" & linefeed
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
echo "=== 空闲时间查询 ($DATE) ==="
echo "日历：$CALENDAR_NAME"
echo "所需时长：$DURATION 分钟"
echo "工作时间：$WORK_START:00 - $WORK_END:00"
echo ""
echo "$RESULT"
