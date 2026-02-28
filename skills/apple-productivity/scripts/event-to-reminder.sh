#!/bin/bash
# event-to-reminder.sh - 将日历事件转换为提醒事项

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"
DEFAULT_REMINDER_LIST="提醒事项"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//' | tr -d '"' || echo "日历")
    DEFAULT_REMINDER_LIST=$(grep "^default_reminder_list:" "$CONFIG_FILE" | sed 's/default_reminder_list: *//' | tr -d '"' || echo "提醒事项")
fi

# 参数解析
EVENT_TITLE=""
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
DATE=""
CREATE_PREP_TASK=false
CREATE_FOLLOWUP_TASK=false
PREP_HOURS_BEFORE=1
FOLLOWUP_HOURS_AFTER=2

usage() {
    echo "用法：$0 --title \"事件标题\" [选项]"
    echo ""
    echo "选项:"
    echo "  --title, -t       事件标题（必需）"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，帮助查找事件）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --create-prep-task    创建会前准备任务"
    echo "  --create-followup-task 创建会后跟进任务"
    echo "  --prep-hours        会前多少小时创建准备任务（默认：$PREP_HOURS_BEFORE）"
    echo "  --followup-hours    会后多少小时创建跟进任务（默认：$FOLLOWUP_HOURS_AFTER）"
    echo "  --help, -h          显示帮助信息"
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
        --create-prep-task)
            CREATE_PREP_TASK=true
            shift
            ;;
        --create-followup-task)
            CREATE_FOLLOWUP_TASK=true
            shift
            ;;
        --prep-hours)
            PREP_HOURS_BEFORE="$2"
            shift 2
            ;;
        --followup-hours)
            FOLLOWUP_HOURS_AFTER="$2"
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
ESCAPED_LIST="${DEFAULT_REMINDER_LIST//\"/\\\"}"

# 创建 AppleScript 获取事件信息
if [ -n "$DATE" ]; then
    GET_EVENT_SCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set searchDate to date "$DATE 00:00:00"
        set nextDay to searchDate + 24 * 60 * 60

        set targetEvent to first event of targetCalendar whose summary = "$ESCAPED_TITLE" and start date ≥ searchDate and start date < nextDay

        set eventName to summary of targetEvent
        set eventStart to start date of targetEvent
        set eventEnd to end date of targetEvent
        set eventLocation to location of targetEvent
        set eventNote to note of targetEvent

        return eventName & "|" & (eventStart as string) & "|" & (eventEnd as string) & "|" & eventLocation & "|" & eventNote
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)
else
    GET_EVENT_SCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set targetEvent to first event of targetCalendar whose summary = "$ESCAPED_TITLE"

        set eventName to summary of targetEvent
        set eventStart to start date of targetEvent
        set eventEnd to end date of targetEvent
        set eventLocation to location of targetEvent
        set eventNote to note of targetEvent

        return eventName & "|" & (eventStart as string) & "|" & (eventEnd as string) & "|" & eventLocation & "|" & eventNote
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)
fi

# 执行 AppleScript 获取事件信息
RESULT=$(osascript -e "$GET_EVENT_SCRIPT" 2>&1)

if [[ "$RESULT" == ERROR:* ]]; then
    echo "❌ 获取事件失败：${RESULT#ERROR:}"
    exit 1
fi

# 解析返回结果
IFS='|' read -r NAME START_TIME END_TIME LOCATION NOTE <<< "$RESULT"

echo "✅ 找到事件：$NAME"
echo "   时间：$START_TIME - $END_TIME"
[ -n "$LOCATION" ] && echo "   地点：$LOCATION"

# 创建提醒任务
CREATED_TASKS=()

# 构建备注内容
BODY_CONTENT="会议时间：$START_TIME"
[ -n "$LOCATION" ] && BODY_CONTENT="$BODY_CONTENT
地点：$LOCATION"
[ -n "$NOTE" ] && BODY_CONTENT="$BODY_CONTENT
备注：$NOTE"

ESCAPED_BODY_CONTENT="${BODY_CONTENT//\"/\\\"}"

# 创建主任务（会后跟进）
if [ "$CREATE_FOLLOWUP_TASK" = true ]; then
    FOLLOWUP_SCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set targetList to list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
        set newReminder to make new reminder at end of reminders of targetList with properties {
            name:"[会后跟进] $NAME",
            body:"$ESCAPED_BODY_CONTENT"
        }
        set due date of newReminder to date "$END_TIME" + $FOLLOWUP_HOURS_AFTER * 60 * 60
        get "跟进任务已创建"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)

    FOLLOWUP_RESULT=$(osascript -e "$FOLLOWUP_SCRIPT" 2>&1)
    if [[ "$FOLLOWUP_RESULT" != ERROR:* ]]; then
        CREATED_TASKS+=("会后跟进任务")
        echo "   ✓ 已创建：会后跟进任务"
    fi
fi

# 创建会前准备任务
if [ "$CREATE_PREP_TASK" = true ]; then
    PREP_SCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set targetList to list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
        set newReminder to make new reminder at end of reminders of targetList with properties {
            name:"[会前准备] $NAME",
            body:"$ESCAPED_BODY_CONTENT"
        }
        set due date of newReminder to date "$START_TIME" - $PREP_HOURS_BEFORE * 60 * 60
        set priority of newReminder to 2
        get "准备任务已创建"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)

    PREP_RESULT=$(osascript -e "$PREP_SCRIPT" 2>&1)
    if [[ "$PREP_RESULT" != ERROR:* ]]; then
        CREATED_TASKS+=("会前准备任务")
        echo "   ✓ 已创建：会前准备任务"
    fi
fi

# 如果没有创建任何任务
if [ ${#CREATED_TASKS[@]} -eq 0 ]; then
    echo ""
    echo "提示：使用 --create-prep-task 和 --create-followup-task 来创建关联任务"
fi

echo ""
echo "✅ 完成！共创建 ${#CREATED_TASKS[@]} 个任务"
