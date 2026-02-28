#!/bin/bash
# search-reminders.sh - 搜索提醒事项

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.local.md"

# 默认值
DEFAULT_ACCOUNT="iCloud"

# 解析配置
if [ -f "$CONFIG_FILE" ]; then
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
fi

# 参数解析
QUERY=""
ACCOUNT="$DEFAULT_ACCOUNT"
IN_LIST=""

usage() {
    echo "用法：$0 --query \"关键词\" [选项]"
    echo ""
    echo "选项:"
    echo "  --query, -q       搜索关键词（必需）"
    echo "  --account, -a     账户名称（默认：$DEFAULT_ACCOUNT）"
    echo "  --in, -i          在指定列表中搜索"
    echo "  --help, -h        显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --query|-q)
            QUERY="$2"
            shift 2
            ;;
        --account|-a)
            ACCOUNT="$2"
            shift 2
            ;;
        --in|-i)
            IN_LIST="$2"
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
if [ -z "$QUERY" ]; then
    echo "错误：必须指定 --query 参数"
    usage
fi

# 转义特殊字符
ESCAPED_QUERY="${QUERY//\"/\\\"}"
ESCAPED_ACCOUNT="${ACCOUNT//\"/\\\"}"
ESCAPED_LIST="${IN_LIST//\"/\\\"}"

# 创建 AppleScript
if [ -n "$IN_LIST" ]; then
    APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set found to search for "$ESCAPED_QUERY" in list "$ESCAPED_LIST" of account "$ESCAPED_ACCOUNT"

        if (count of found) is 0 then
            log "未找到匹配的任务"
        else
            repeat with r in found
                set statusIcon to "○"
                if completed of r then set statusIcon to "●"

                set priorityText to ""
                if priority of r is 1 then set priorityText to "[低]"
                if priority of r is 2 then set priorityText to "[中]"
                if priority of r is 3 then set priorityText to "[高]"

                set dueText to ""
                if due date of r is not missing value then
                    set dueText to " (截止：" & (due date of r) & ")"
                end if

                log statusIcon & " " & name of r & " [" & (name of container of r) & "]" & priorityText & dueText
            end repeat
        end if

        return count of found
    end try
end tell
EOF
)
else
    APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    try
        set found to search for "$ESCAPED_QUERY" in account "$ESCAPED_ACCOUNT"

        if (count of found) is 0 then
            log "未找到匹配的任务"
        else
            repeat with r in found
                set statusIcon to "○"
                if completed of r then set statusIcon to "●"

                set priorityText to ""
                if priority of r is 1 then set priorityText to "[低]"
                if priority of r is 2 then set priorityText to "[中]"
                if priority of r is 3 then set priorityText to "[高]"

                set dueText to ""
                if due date of r is not missing value then
                    set dueText to " (截止：" & (due date of r) & ")"
                end if

                log statusIcon & " " & name of r & " [" & (name of container of r) & "]" & priorityText & dueText
            end repeat
        end if

        return count of found
    end try
end tell
EOF
)
fi

# 执行 AppleScript
RESULT=$(osascript -e "$APPLESCRIPT" 2>&1)

# 分离输出和计数
OUTPUT_LINES=$(echo "$RESULT" | grep -v "^$")
COUNT=$(echo "$RESULT" | tail -1)

echo ""
echo "=== 搜索结果：'$QUERY' ==="
if [ -n "$OUTPUT_LINES" ]; then
    echo "$OUTPUT_LINES" | head -n -1 2>/dev/null || echo "$OUTPUT_LINES"
fi
echo ""
echo "找到 $COUNT 个匹配的任务"
