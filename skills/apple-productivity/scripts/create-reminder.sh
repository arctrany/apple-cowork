#!/bin/bash
# create-reminder.sh - 创建新的提醒事项

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_LIST="提醒事项"
DEFAULT_PRIORITY=0

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//; s/ *#.*//' | tr -d '"' || echo "iCloud")
    DEFAULT_LIST=$(grep "^default_reminder_list:" "$CONFIG_FILE" | sed 's/default_reminder_list: *//; s/ *#.*//' | tr -d '"' || echo "提醒事项")
    DEFAULT_PRIORITY=$(grep "^default_reminder_priority:" "$CONFIG_FILE" | sed 's/default_reminder_priority: *//; s/ *#.*//' || echo "0")
fi

# 参数解析
REMINDER_NAME=""
REMINDER_LIST="$DEFAULT_LIST"
ACCOUNT="$DEFAULT_ACCOUNT"
DUE_DATE=""
PRIORITY="$DEFAULT_PRIORITY"
NOTE=""
PARSE_INPUT=""

usage() {
    echo "用法：$0 --name \"任务名称\" [选项]"
    echo ""
    echo "选项:"
    echo "  --name, -n        任务名称（必需，除非使用 --parse）"
    echo "  --parse, -p       自然语言输入（例如：'明天下午 3 点完成报告'）"
    echo "  --list, -l        列表名称（默认：$DEFAULT_LIST）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --due, -d         截止时间（格式：YYYY-MM-DD HH:MM）"
    echo "  --priority        优先级（0=无，1=低，2=中，3=高，默认：$DEFAULT_PRIORITY）"
    echo "  --note            备注内容"
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
        --parse|-p)
            PARSE_INPUT="$2"
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
        --due|-d)
            DUE_DATE="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
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
    REMINDER_NAME="$PARSE_INPUT"

    # 检测"明天"
    if [[ "$PARSE_INPUT" == *"明天"* ]]; then
        DUE_DATE=$(date -v+1d +"%Y-%m-%d")" 23:59"
    elif [[ "$PARSE_INPUT" == *"今天"* ]]; then
        DUE_DATE=$(date +"%Y-%m-%d")" 23:59"
    elif [[ "$PARSE_INPUT" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        DUE_DATE="${BASH_REMATCH[1]}"
    fi

    # 检测具体时间（例如"下午 3 点"）
    if [[ "$PARSE_INPUT" =~ 下午\ ([0-9]+)\ 点 ]]; then
        HOUR=$((${BASH_REMATCH[1]} + 12))
        DUE_DATE="${DUE_DATE:-$(date +%Y-%m-%d)} ${HOUR}:00"
    elif [[ "$PARSE_INPUT" =~ 上午\ ([0-9]+)\ 点 ]]; then
        HOUR=${BASH_REMATCH[1]}
        DUE_DATE="${DUE_DATE:-$(date +%Y-%m-%d)} ${HOUR}:00"
    elif [[ "$PARSE_INPUT" =~ ([0-9]+):([0-9]+) ]]; then
        DUE_DATE="${DUE_DATE:-$(date +%Y-%m-%d)} ${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    fi
fi

# 验证必需参数
if [ -z "$REMINDER_NAME" ]; then
    echo "错误：必须指定 --name 或 --parse 参数"
    usage
fi

# 转义特殊字符
ESCAPED_NOTE="${NOTE//\"/\\\"}"
ESCAPED_NAME="${REMINDER_NAME//\"/\\\"}"
ESCAPED_LIST="${REMINDER_LIST//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
if [ -n "$ESCAPED_NOTE" ]; then
    NOTE_SECTION="set body of newReminder to \"$ESCAPED_NOTE\""
else
    NOTE_SECTION=""
fi

if [ -n "$DUE_DATE" ]; then
    DUE_SECTION="set due date of newReminder to date \"$DUE_DATE\""
else
    DUE_SECTION=""
fi

APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    set targetList to list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
    set newReminder to make new reminder at end of reminders of targetList with properties {name:"$ESCAPED_NAME"}
    $NOTE_SECTION
    if $PRIORITY > 0 then
        set priority of newReminder to $PRIORITY
    end if
    $DUE_SECTION
    get id of newReminder
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ 成功创建任务：$REMINDER_NAME"
    echo "   列表：$REMINDER_LIST"
    echo "   账户：$ACCOUNT"
    [ -n "$DUE_DATE" ] && echo "   截止时间：$DUE_DATE"
    [ "$PRIORITY" -gt 0 ] && echo "   优先级：$PRIORITY"
    [ -n "$NOTE" ] && echo "   备注：$NOTE"
    echo "   ID: $RESULT"
else
    echo "❌ 创建任务失败：$RESULT"
    exit 1
fi
