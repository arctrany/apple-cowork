#!/bin/bash
# get-reminder.sh - 获取单个提醒事项的详细信息

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

usage() {
    echo "用法：$0 --name \"任务名称\" [选项]"
    echo ""
    echo "选项:"
    echo "  --name, -n        任务名称（必需）"
    echo "  --list, -l        列表名称（默认：$DEFAULT_LIST）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
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
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"

# 创建 AppleScript
APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set r to reminder "$ESCAPED_NAME" of list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"

        set info to "名称：" & name of r & linefeed

        set info to info & "列表：" & (name of container of r) & linefeed

        if body of r is not missing value and body of r != "" then
            set info to info & "备注：" & body of r & linefeed
        end if

        set priorityText to "无"
        if priority of r is 1 then set priorityText to "低"
        if priority of r is 2 then set priorityText to "中"
        if priority of r is 3 then set priorityText to "高"
        set info to info & "优先级：" & priorityText & linefeed

        if due date of r is not missing value then
            set info to info & "截止时间：" & (due date of r) & linefeed
        end if

        if reminder date of r is not missing value then
            set info to info & "提醒时间：" & (reminder date of r) & linefeed
        end if

        if completed of r then
            set info to info & "状态：已完成" & linefeed
        else
            set info to info & "状态：待完成" & linefeed
        end if

        set info to info & "ID：" & id of r

        return info
    on error errMsg
        return "错误：" & errMsg
    end try
end tell
EOF
)

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

if [[ "$RESULT" == 错误：* ]]; then
    echo "❌ $RESULT"
    exit 1
fi

echo "=== 任务详情 ==="
echo "$RESULT"
