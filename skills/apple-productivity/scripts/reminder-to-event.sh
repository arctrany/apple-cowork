#!/bin/bash
# reminder-to-event.sh - 将提醒事项转换为日历事件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"
DEFAULT_REMINDER_LIST="提醒事项"
DEFAULT_DURATION=60

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//' | tr -d '"' || echo "日历")
    DEFAULT_REMINDER_LIST=$(grep "^default_reminder_list:" "$CONFIG_FILE" | sed 's/default_reminder_list: *//' | tr -d '"' || echo "提醒事项")
    DEFAULT_DURATION=$(grep "^default_event_duration:" "$CONFIG_FILE" | sed 's/default_event_duration: *//' || echo "60")
fi

# 参数解析
REMINDER_NAME=""
REMINDER_LIST="$DEFAULT_REMINDER_LIST"
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DURATION=$DEFAULT_DURATION
USE_DUE_DATE=false

usage() {
    echo "用法：$0 --name \"任务名称\" [选项]"
    echo ""
    echo "选项:"
    echo "  --name, -n        任务名称（必需）"
    echo "  --list, -l        提醒列表名称（默认：$DEFAULT_REMINDER_LIST）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --duration        事件时长（分钟，默认：$DURATION）"
    echo "  --use-due-date    使用任务的截止时间作为事件开始时间"
    echo "  --help, -h        显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --name|-n)
            REMINDER_NAME="$2"
            shift 2
            ;;
        --list|-l)
            REMINDER_LIST="$2"
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
        --use-due-date)
            USE_DUE_DATE=true
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
if [ -z "$REMINDER_NAME" ]; then
    echo "错误：必须指定 --name 参数"
    usage
fi

# 转义特殊字符
ESCAPED_NAME="${REMINDER_NAME//\"/\\\"}"
ESCAPED_LIST="${REMINDER_LIST//\"/\\\"}"
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set r to reminder "$ESCAPED_NAME" of list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"

        set reminderName to name of r
        set reminderBody to body of r
        set reminderDue to due date of r

        -- 确定事件开始时间
        if $USE_DUE_DATE and reminderDue is not missing value then
            set eventStart to reminderDue
        else
            set eventStart to (current date) + 60 * 60  -- 默认 1 小时后
        end if

        set eventEnd to eventStart + $DURATION * 60

        -- 返回信息给 Shell
        return reminderName & "|" & reminderBody & "|" & (eventStart as string) & "|" & (eventEnd as string)
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)

# 执行 AppleScript 获取任务信息
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

if [[ "$RESULT" == ERROR:* ]]; then
    echo "❌ 获取任务失败：${RESULT#ERROR:}"
    exit 1
fi

# 解析返回结果
IFS='|' read -r NAME BODY START_TIME END_TIME <<< "$RESULT"

# 创建日历事件
EVENT_SCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set eventStart to date "$START_TIME"
        set eventEnd to date "$END_TIME"

        set newEvent to make new event at end of events of targetCalendar with properties {
            summary:"[任务] $NAME",
            start date:eventStart,
            end date:eventEnd,
            note:"从 Reminders 转换而来" & (if "$BODY" != "" then return linefeed & "原任务备注：" & "$BODY" else return "")
        }

        get id of newEvent
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)

EVENT_RESULT=$(osascript -e "$EVENT_SCRIPT" 2>&1)

if [[ "$EVENT_RESULT" == ERROR:* ]]; then
    echo "❌ 创建事件失败：${EVENT_RESULT#ERROR:}"
    exit 1
fi

echo "✅ 成功将任务转换为事件"
echo "   任务：$REMINDER_NAME"
echo "   事件：[任务] $NAME"
echo "   日历：$CALENDAR_NAME"
echo "   时间：$START_TIME - $END_TIME"
echo "   ID: $EVENT_RESULT"
