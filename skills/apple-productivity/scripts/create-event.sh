#!/bin/bash
# create-event.sh - 创建日历事件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_CALENDAR="日历"
DEFAULT_DURATION=60

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//; s/ *#.*//' | tr -d '"' || echo "iCloud")
    DEFAULT_CALENDAR=$(grep "^default_calendar:" "$CONFIG_FILE" | sed 's/default_calendar: *//; s/ *#.*//' | tr -d '"' || echo "日历")
    DEFAULT_DURATION=$(grep "^default_event_duration:" "$CONFIG_FILE" | sed 's/default_event_duration: *//; s/ *#.*//' || echo "60")
fi

# 参数解析
EVENT_TITLE=""
CALENDAR_NAME="$DEFAULT_CALENDAR"
ACCOUNT="$DEFAULT_ACCOUNT"
START_TIME=""
END_TIME=""
LOCATION=""
PARTICIPANTS=""
NOTE=""
PARSE_INPUT=""

usage() {
    echo "用法：$0 --title \"事件标题\" --start \"开始时间\" --end \"结束时间\" [选项]"
    echo ""
    echo "选项:"
    echo "  --title, -t       事件标题（必需，除非使用 --parse）"
    echo "  --parse, -p       自然语言输入（例如：'明天下午 2 点到 3 点开会议'）"
    echo "  --calendar, -c    日历名称（默认：$DEFAULT_CALENDAR）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --start, -s       开始时间（格式：YYYY-MM-DD HH:MM）"
    echo "  --end, -e         结束时间（格式：YYYY-MM-DD HH:MM）"
    echo "  --location        地点"
    echo "  --participants    参与者（逗号分隔）"
    echo "  --note            备注内容"
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
        --parse|-p)
            PARSE_INPUT="$2"
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
        --start|-s)
            START_TIME="$2"
            shift 2
            ;;
        --end|-e)
            END_TIME="$2"
            shift 2
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --participants)
            PARTICIPANTS="$2"
            shift 2
            ;;
        --note)
            NOTE="$2"
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

# 自然语言解析（简化版）
if [ -n "$PARSE_INPUT" ]; then
    EVENT_TITLE="$PARSE_INPUT"

    # 检测"明天"
    if [[ "$PARSE_INPUT" == *"明天"* ]]; then
        BASE_DATE=$(date -v+1d +"%Y-%m-%d")
    elif [[ "$PARSE_INPUT" == *"今天"* ]]; then
        BASE_DATE=$(date +"%Y-%m-%d")
    elif [[ "$PARSE_INPUT" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        BASE_DATE="${BASH_REMATCH[1]}"
    else
        BASE_DATE=$(date +"%Y-%m-%d")
    fi

    # 检测时间（例如"下午 2 点"）
    if [[ "$PARSE_INPUT" =~ 下午\ ([0-9]+)\ 点 ]]; then
        START_HOUR=$((${BASH_REMATCH[1]} + 12))
        START_TIME="${BASE_DATE} ${START_HOUR}:00"
    elif [[ "$PARSE_INPUT" =~ 上午\ ([0-9]+)\ 点 ]]; then
        START_HOUR=${BASH_REMATCH[1]}
        START_TIME="${BASE_DATE} ${START_HOUR}:00"
    elif [[ "$PARSE_INPUT" =~ ([0-9]+):([0-9]+) ]]; then
        START_TIME="${BASE_DATE} ${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    fi

    # 检测结束时间（例如"到 3 点"）
    if [[ "$PARSE_INPUT" =~ 到\ [下上]?午?\ ?([0-9]+)\ 点 ]]; then
        END_HOUR=$((${BASH_REMATCH[1]} + 12))
        END_TIME="${BASE_DATE} ${END_HOUR}:00"
    elif [[ "$PARSE_INPUT" =~ 到\ ?([0-9]+):([0-9]+) ]]; then
        END_TIME="${BASE_DATE} ${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    fi

    # 如果没有结束时间，使用默认时长
    if [ -z "$END_TIME" ] && [ -n "$START_TIME" ]; then
        END_TIME=$(date -v+${DEFAULT_DURATION}M -j -f "%Y-%m-%d %H:%M" "$START_TIME" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "${BASE_DATE} $(printf "%02d" $(($(date -j -f "%H:%M" "${START_TIME#*-}" +"%H" 2>/dev/null || echo "0") + 1))):00")
    fi

    # 提取地点（例如"在办公室"）
    if [[ "$PARSE_INPUT" =~ 在\ ([^，,]+) ]]; then
        LOCATION="${BASH_REMATCH[1]}"
    fi
fi

# 验证必需参数
if [ -z "$EVENT_TITLE" ]; then
    echo "错误：必须指定 --title 或 --parse 参数"
    usage
fi

if [ -z "$START_TIME" ]; then
    echo "错误：必须指定 --start 时间或使用 --parse 自然语言输入"
    usage
fi

if [ -z "$END_TIME" ]; then
    # 默认结束时间为开始后 1 小时
    END_TIME=$(date -v+${DEFAULT_DURATION}M -j -f "%Y-%m-%d %H:%M" "$START_TIME" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "$START_TIME")
fi

# 转义特殊字符
ESCAPED_TITLE="${EVENT_TITLE//\"/\\\"}"
ESCAPED_CALENDAR="${CALENDAR_NAME//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"
ESCAPED_LOCATION="${LOCATION//\"/\\\"}"
ESCAPED_NOTE="${NOTE//\"/\\\"}"

# 创建 AppleScript 脚本
# 注意：Calendar AppleScript 不支持在创建时设置 note 属性
if [ -n "$ESCAPED_LOCATION" ]; then
    PROPERTIES="summary:\"$ESCAPED_TITLE\", start date:eventStart, end date:eventEnd, location:\"$ESCAPED_LOCATION\""
else
    PROPERTIES="summary:\"$ESCAPED_TITLE\", start date:eventStart, end date:eventEnd"
fi

APPLESCRIPT=$(cat <<EOF
tell application "Calendar"
    set targetCalendar to calendar "$ESCAPED_CALENDAR"
    set eventStart to date "$START_TIME"
    set eventEnd to date "$END_TIME"
    try
        set newEvent to make new event at end of events of targetCalendar with properties {$PROPERTIES}
        get id of newEvent
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

if [[ "$RESULT" == *"错误："* ]]; then
    echo "❌ 创建事件失败：$RESULT"
    exit 1
fi

echo "✅ 成功创建事件：$EVENT_TITLE"
echo "   日历：$CALENDAR_NAME"
echo "   开始：$START_TIME"
echo "   结束：$END_TIME"
[ -n "$LOCATION" ] && echo "   地点：$LOCATION"
[ -n "$NOTE" ] && echo "   备注：$NOTE"
echo "   ID: $RESULT"
