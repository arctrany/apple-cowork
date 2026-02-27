#!/bin/bash
# update-reminder.sh - 更新提醒事项

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"
DEFAULT_LIST="提醒事项"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_LIST=$(grep "^default_reminder_list:" "$CONFIG_FILE" | sed 's/default_reminder_list: *//' | tr -d '"' || echo "提醒事项")
fi

# 参数解析
REMINDER_NAME=""
REMINDER_LIST="$DEFAULT_LIST"
ACCOUNT="$DEFAULT_ACCOUNT"
NEW_NAME=""
NEW_DUE_DATE=""
NEW_PRIORITY=""
NEW_NOTE=""
NEW_LIST=""

usage() {
    echo "用法：$0 --name \"任务名称\" [更新选项]"
    echo ""
    echo "选项:"
    echo "  --name, -n        任务名称（必需）"
    echo "  --list, -l        列表名称（默认：$DEFAULT_LIST）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --new-name        新任务名称"
    echo "  --due, -d         新截止时间（格式：YYYY-MM-DD HH:MM）"
    echo "  --priority        新优先级（0=无，1=低，2=中，3=高）"
    echo "  --note            新备注内容"
    echo "  --new-list        新列表名称"
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
        --account|-a)
            ACCOUNT="$2"
            shift 2
            ;;
        --new-name)
            NEW_NAME="$2"
            shift 2
            ;;
        --due|-d)
            NEW_DUE_DATE="$2"
            shift 2
            ;;
        --priority)
            NEW_PRIORITY="$2"
            shift 2
            ;;
        --note)
            NEW_NOTE="$2"
            shift 2
            ;;
        --new-list)
            NEW_LIST="$2"
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
if [ -z "$REMINDER_NAME" ]; then
    echo "错误：必须指定 --name 参数"
    usage
fi

# 验证至少有一个更新项
if [ -z "$NEW_NAME" ] && [ -z "$NEW_DUE_DATE" ] && [ -z "$NEW_PRIORITY" ] && [ -z "$NEW_NOTE" ] && [ -z "$NEW_LIST" ]; then
    echo "错误：必须指定至少一个更新选项"
    usage
fi

# 转义特殊字符
ESCAPED_NAME="${REMINDER_NAME//\"/\\\"}"
ESCAPED_LIST="${REMINDER_LIST//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"
ESCAPED_NEW_NAME="${NEW_NAME//\"/\\\"}"
ESCAPED_NEW_NOTE="${NEW_NOTE//\"/\\\"}"
ESCAPED_NEW_LIST="${NEW_LIST//\"/\\\"}"

# 构建 AppleScript 更新语句
UPDATE_STATEMENTS=""

if [ -n "$NEW_NAME" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set name of r to \"$ESCAPED_NEW_NAME\""
fi

if [ -n "$NEW_DUE_DATE" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set due date of r to date \"$NEW_DUE_DATE\""
fi

if [ -n "$NEW_PRIORITY" ]; then
    if [ "$NEW_PRIORITY" -gt 0 ]; then
        UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set priority of r to $NEW_PRIORITY"
    else
        UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set priority of r to 0"
    fi
fi

if [ -n "$NEW_NOTE" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    set body of r to \"$ESCAPED_NEW_NOTE\""
fi

if [ -n "$NEW_LIST" ]; then
    UPDATE_STATEMENTS="$UPDATE_STATEMENTS
    move r to list \"$ESCAPED_NEW_LIST\" of account \"$ESCAPED_ACCOUNT\""
fi

# 创建 AppleScript
APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set r to reminder "$ESCAPED_NAME" of list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
        $UPDATE_STATEMENTS
        return "更新成功"
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

if [[ "$RESULT" == *"错误："* ]]; then
    echo "❌ $RESULT"
    exit 1
fi

echo "✅ 成功更新任务：$REMINDER_NAME"
[ -n "$NEW_NAME" ] && echo "   新名称：$NEW_NAME"
[ -n "$NEW_DUE_DATE" ] && echo "   新截止时间：$NEW_DUE_DATE"
[ -n "$NEW_PRIORITY" ] && echo "   新优先级：$NEW_PRIORITY"
[ -n "$NEW_NOTE" ] && echo "   新备注：$NEW_NOTE"
[ -n "$NEW_LIST" ] && echo "   新列表：$NEW_LIST"
