#!/bin/bash
# complete-reminder.sh - 完成/取消完成提醒事项

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
TOGGLE=false
COMPLETE=false
UNCOMPLETE=false

usage() {
    echo "用法：$0 --name \"任务名称\" [选项]"
    echo ""
    echo "选项:"
    echo "  --name, -n        任务名称（必需）"
    echo "  --list, -l        列表名称（默认：$DEFAULT_LIST）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --toggle, -t      切换完成状态（已完成→未完成，未完成→已完成）"
    echo "  --complete, -c    标记为已完成"
    echo "  --uncomplete, -u  标记为未完成"
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
        --toggle|-t)
            TOGGLE=true
            shift
            ;;
        --complete|-c)
            COMPLETE=true
            shift
            ;;
        --uncomplete|-u)
            UNCOMPLETE=true
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

# 确定操作类型
if [ "$TOGGLE" = true ]; then
    ACTION="toggle"
elif [ "$COMPLETE" = true ]; then
    ACTION="complete"
elif [ "$UNCOMPLETE" = true ]; then
    ACTION="uncomplete"
else
    # 默认 toggle
    ACTION="toggle"
fi

# 转义特殊字符
ESCAPED_NAME="${REMINDER_NAME//\"/\\\"}"
ESCAPED_LIST="${REMINDER_LIST//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
if [ "$ACTION" = "toggle" ]; then
    APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set r to reminder "$ESCAPED_NAME" of list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
        set completed of r to not (completed of r)

        if completed of r then
            return "已完成 ✓"
        else
            return "已取消完成 ○"
        end if
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)
elif [ "$ACTION" = "complete" ]; then
    APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set r to reminder "$ESCAPED_NAME" of list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
        set completed of r to true
        return "已完成 ✓"
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)
else
    APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set r to reminder "$ESCAPED_NAME" of list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"
        set completed of r to false
        return "已取消完成 ○"
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

echo "✅ 任务：$REMINDER_NAME - $RESULT"
