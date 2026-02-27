#!/bin/bash
# sync-view.sh - 同步视图（显示指定日期的任务和事件）

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
DATE=""
CALENDAR_NAME="$DEFAULT_CALENDAR"
REMINDER_LIST="$DEFAULT_REMINDER_LIST"
ACCOUNT="$DEFAULT_ACCOUNT"
SHOW_REMINDERS=true
SHOW_EVENTS=true

usage() {
    echo "用法：$0 --date \"日期\" [选项]"
    echo ""
    echo "选项:"
    echo "  --date, -d        日期（格式：YYYY-MM-DD，必需）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --list, -l        提醒列表名称（默认：$DEFAULT_REMINDER_LIST）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --no-reminders    不显示任务"
    echo "  --no-events       不显示事件"
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
        --list|-l)
            REMINDER_LIST="$2"
            shift 2
            ;;
        --account|-a)
            ACCOUNT="$2"
            shift 2
            ;;
        --no-reminders)
            SHOW_REMINDERS=false
            shift
            ;;
        --no-events)
            SHOW_EVENTS=false
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
if [ -z "$DATE" ]; then
    echo "错误：必须指定 --date 参数"
    usage
fi

# 转义特殊字符
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_LIST="${REMINDER_LIST//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 设置日期范围
START_DATE="${DATE} 00:00:00"
END_DATE="${DATE} 23:59:59"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              同步视图 - $DATE                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 获取事件
if [ "$SHOW_EVENTS" = true ]; then
    echo "📅 日历事件 ($CALENDAR_NAME)"
    echo "─────────────────────────────────────────────────────────"

    EVENT_SCRIPT=$(cat <<EOF
tell application "Calendar"
    try
        set targetCalendar to calendar "$ESCAPED_CALENDAR"
        set startDate to date "$START_DATE"
        set endDate to date "$END_DATE"

        set dayEvents to every event of targetCalendar whose start date ≥ startDate and start date ≤ endDate

        if (count of dayEvents) is 0 then
            return "  暂无事件"
        else
            set resultText to ""
            repeat with e in dayEvents
                set eventTime to text -11 thru -6 of (start date of e as string)
                set eventSummary to summary of e
                set eventLocation to location of e

                set lineText to "  " & eventTime & " " & eventSummary
                if eventLocation is not "" then
                    set lineText to lineText & " @" & eventLocation
                end if
                set resultText to resultText & lineText & linefeed
            end repeat
            return resultText
        end if
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)

    EVENT_RESULT=$(osascript -e "$EVENT_SCRIPT" 2>&1)
    echo "$EVENT_RESULT"
    echo ""
fi

# 获取任务
if [ "$SHOW_REMINDERS" = true ]; then
    echo "✅ 任务 ($REMINDER_LIST)"
    echo "─────────────────────────────────────────────────────────"

    REMINDER_SCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set targetList to list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"

        -- 获取所有待完成任务
        set pendingReminders to every reminder of targetList whose completed is false

        -- 筛选今天到期的任务
        set todayStart to date "$START_DATE"
        set todayEnd to date "$END_DATE"

        set todayReminders to {}
        set overdueReminders to {}
        set futureReminders to {}

        repeat with r in pendingReminders
            if due date of r is not missing value then
                if due date of r < todayStart then
                    set end of overdueReminders to r
                else if due date of r ≥ todayStart and due date of r ≤ todayEnd then
                    set end of todayReminders to r
                else
                    set end of futureReminders to r
                end if
            else
                -- 没有截止时间的任务归为"无截止时间"
                set end of futureReminders to r
            end if
        end repeat

        set resultText to ""

        -- 显示过期任务
        if (count of overdueReminders) > 0 then
            set resultText to resultText & "  [过期] " & linefeed
            repeat with r in overdueReminders
                set priorityText to ""
                if priority of r is 3 then set priorityText to "🔴 "
                if priority of r is 2 then set priorityText to "🟡 "
                if priority of r is 1 then set priorityText to "🟢 "
                set dueDate to text 1 thru 10 of (due date of r as string)
                set resultText to resultText & "    " & priorityText & "○ " & name of r & " (截止：" & dueDate & ")" & linefeed
            end repeat
        end if

        -- 显示今天任务
        if (count of todayReminders) > 0 then
            set resultText to resultText & "  [今天] " & linefeed
            repeat with r in todayReminders
                set priorityText to ""
                if priority of r is 3 then set priorityText to "🔴 "
                if priority of r is 2 then set priorityText to "🟡 "
                if priority of r is 1 then set priorityText to "🟢 "
                set dueTime to text -11 thru -6 of (due date of r as string)
                set resultText to resultText & "    " & priorityText & "○ " & name of r & " (截止：" & dueTime & ")" & linefeed
            end repeat
        end if

        -- 显示未来任务（最多 5 个）
        if (count of futureReminders) > 0 then
            set resultText to resultText & "  [待安排] " & linefeed
            set count to 0
            repeat with r in futureReminders
                if count ≥ 5 then exit repeat
                set priorityText to ""
                if priority of r is 3 then set priorityText to "🔴 "
                if priority of r is 2 then set priorityText to "🟡 "
                if priority of r is 1 then set priorityText to "🟢 "
                set lineText to "    " & priorityText & "○ " & name of r
                if due date of r is not missing value then
                    set dueDate to text 1 thru 10 of (due date of r as string)
                    set lineText to lineText & " (截止：" & dueDate & ")"
                end if
                set resultText to resultText & lineText & linefeed
                set count to count + 1
            end repeat
            if (count of futureReminders) > 5 then
                set resultText to resultText & "    ... 还有 " & ((count of futureReminders) - 5) & " 个任务" & linefeed
            end if
        end if

        if resultText is "" then
            return "  暂无任务"
        else
            return resultText
        end if
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)

    REMINDER_RESULT=$(osascript -e "$REMINDER_SCRIPT" 2>&1)
    echo "$REMINDER_RESULT"
    echo ""
fi

echo "╚═══════════════════════════════════════════════════════════╝"
