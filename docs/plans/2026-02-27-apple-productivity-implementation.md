# Apple Productivity 技能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建完整的 apple-productivity 技能，整合 Apple Reminders 和 Apple Calendar 功能

**Architecture:** 采用与 apple-notes 技能一致的架构模式，使用 AppleScript 作为核心交互层，Shell 脚本作为执行层，统一配置文件管理默认值

**Tech Stack:** AppleScript + Shell Script + YAML 配置

---

## Task 1: 创建技能目录结构

**Files:**
- Create: `skills/apple-productivity/`
- Create: `skills/apple-productivity/scripts/`
- Create: `skills/apple-productivity/references/`
- Create: `skills/apple-productivity/templates/`

**Step 1: 创建目录结构**

```bash
mkdir -p skills/apple-productivity/{scripts,references,templates}
```

**Step 2: 验证目录创建**

```bash
ls -la skills/apple-productivity/
```

Expected: 显示 scripts、references、templates 三个子目录

**Step 3: 提交**

```bash
git add skills/apple-productivity
git commit -m "feat: create apple-productivity skill directory structure"
```

---

## Task 2: 创建配置文件 .local.md

**Files:**
- Create: `skills/apple-productivity/.local.md`

**Step 1: 创建配置文件**

```markdown
---
# 默认账户设置
default_account: iCloud

# Reminders 默认设置
default_reminder_list: 提醒事项
default_reminder_priority: 0  # 0=无，1=低，2=中，3=高

# Calendar 默认设置
default_calendar: 日历
default_event_duration: 60  # 分钟

# 跨模块整合设置
enable_cross_module: true
auto_create_reminders_from_events: false
```

**Step 2: 提交**

```bash
git add skills/apple-productivity/.local.md
git commit -m "feat: add apple-productivity configuration file"
```

---

## Task 3: 创建 Reminders AppleScript 参考文档

**Files:**
- Create: `skills/apple-productivity/references/reminders-applescript.md`

**Step 1: 创建参考文档**

创建完整的 Reminders AppleScript 参考文档，包含：
- 基础操作（创建、读取、更新、删除）
- 列表管理
- 搜索功能
- 子任务管理
- 错误处理示例

**Step 2: 提交**

```bash
git add skills/apple-productivity/references/reminders-applescript.md
git commit -m "docs: add Reminders AppleScript reference guide"
```

---

## Task 4: 创建 Calendar AppleScript 参考文档

**Files:**
- Create: `skills/apple-productivity/references/calendar-applescript.md`

**Step 1: 创建参考文档**

创建完整的 Calendar AppleScript 参考文档，包含：
- 基础操作（创建、读取、更新、删除事件）
- 日历管理
- 空闲时间查询
- 冲突检测
- 错误处理示例

**Step 2: 提交**

```bash
git add skills/apple-productivity/references/calendar-applescript.md
git commit -m "docs: add Calendar AppleScript reference guide"
```

---

## Task 5: 创建 Reminders 基础脚本 - create-reminder.sh

**Files:**
- Create: `skills/apple-productivity/scripts/create-reminder.sh`

**Step 1: 创建脚本**

```bash
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
    DEFAULT_ACCOUNT=$(grep "^default_account:" "$CONFIG_FILE" | sed 's/default_account: *//' | tr -d '"' || echo "iCloud")
    DEFAULT_LIST=$(grep "^default_reminder_list:" "$CONFIG_FILE" | sed 's/default_reminder_list: *//' | tr -d '"' || echo "提醒事项")
    DEFAULT_PRIORITY=$(grep "^default_reminder_priority:" "$CONFIG_FILE" | sed 's/default_reminder_priority: *//' || echo "0")
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
    # TODO: 实现完整的自然语言解析
    # 这里提取简单的日期和时间信息
    REMINDER_NAME="$PARSE_INPUT"

    # 检测"明天"
    if [[ "$PARSE_INPUT" == *"明天"* ]]; then
        DUE_DATE=$(date -v+1d +"%Y-%m-%d")" 23:59"
    fi

    # 检测具体时间（例如"下午 3 点"）
    if [[ "$PARSE_INPUT" =~ 下午 ([0-9]+) 点 ]]; then
        HOUR=$((${BASH_REMATCH[1]} + 12))
        DUE_DATE="${DUE_DATE:-$(date +%Y-%m-%d)} ${HOUR}:00"
    elif [[ "$PARSE_INPUT" =~ 上午 ([0-9]+) 点 ]]; then
        HOUR=${BASH_REMATCH[1]}
        DUE_DATE="${DUE_DATE:-$(date +%Y-%m-%d)} ${HOUR}:00"
    fi
fi

# 验证必需参数
if [ -z "$REMINDER_NAME" ]; then
    echo "错误：必须指定 --name 或 --parse 参数"
    usage
fi

# 创建 AppleScript
APPLESCRIPT=$(cat <<EOF
tell application "Reminders"
    set targetList to list "$REMINDER_LIST" of account "$ACCOUNT"
    set newReminder to make new reminder at end of reminders of targetList with properties {name:"$REMINDER_NAME"}

    if "$NOTE" != "" then
        set body of newReminder to "$NOTE"
    end if

    if $PRIORITY > 0 then
        set priority of newReminder to $PRIORITY
    end if

    if "$DUE_DATE" != "" then
        set due date of newReminder to date "$DUE_DATE"
    end if

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
else
    echo "❌ 创建任务失败：$RESULT"
    exit 1
fi
```

**Step 2: 添加执行权限**

```bash
chmod +x skills/apple-productivity/scripts/create-reminder.sh
```

**Step 3: 测试脚本**

```bash
cd skills/apple-productivity && ./scripts/create-reminder.sh --name "测试任务" --note "这是一个测试"
```

Expected: 成功创建任务并显示确认信息

**Step 4: 提交**

```bash
git add skills/apple-productivity/scripts/create-reminder.sh
git commit -m "feat: add create-reminder.sh script"
```

---

## Task 6: 创建 Reminders 基础脚本 - list-reminders.sh

**Files:**
- Create: `skills/apple-productivity/scripts/list-reminders.sh`

**Step 1: 创建脚本**

创建列出任务的脚本，支持：
- 按列表过滤
- 按状态过滤（全部/待完成/已完成）
- 显示任务详情（名称、截止时间、优先级、完成状态）

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/list-reminders.sh
./scripts/list-reminders.sh --list "提醒事项" --status "pending"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/list-reminders.sh
git commit -m "feat: add list-reminders.sh script"
```

---

## Task 7: 创建 Reminders 基础脚本 - get-reminder.sh

**Files:**
- Create: `skills/apple-productivity/scripts/get-reminder.sh`

**Step 1: 创建脚本**

创建获取单个任务详情的脚本，支持：
- 按名称查找
- 显示完整信息（名称、备注、截止时间、优先级、完成状态、子任务）

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/get-reminder.sh
./scripts/get-reminder.sh --name "测试任务"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/get-reminder.sh
git commit -m "feat: add get-reminder.sh script"
```

---

## Task 8: 创建 Reminders 基础脚本 - update-reminder.sh

**Files:**
- Create: `skills/apple-productivity/scripts/update-reminder.sh`

**Step 1: 创建脚本**

创建更新任务的脚本，支持：
- 更新任务名称
- 更新截止时间
- 更新优先级
- 更新备注
- 移动到其他列表

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/update-reminder.sh
./scripts/update-reminder.sh --name "测试任务" --priority 3
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/update-reminder.sh
git commit -m "feat: add update-reminder.sh script"
```

---

## Task 9: 创建 Reminders 基础脚本 - complete-reminder.sh

**Files:**
- Create: `skills/apple-productivity/scripts/complete-reminder.sh`

**Step 1: 创建脚本**

创建完成任务的脚本，支持：
- 标记为已完成
- 标记为未完成（toggle）
- 按名称或 ID 查找

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/complete-reminder.sh
./scripts/complete-reminder.sh --name "测试任务" --toggle
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/complete-reminder.sh
git commit -m "feat: add complete-reminder.sh script"
```

---

## Task 10: 创建 Reminders 基础脚本 - delete-reminder.sh

**Files:**
- Create: `skills/apple-productivity/scripts/delete-reminder.sh`

**Step 1: 创建脚本**

创建删除任务的脚本，支持：
- 按名称删除
- 确认提示（--confirm 参数）
- 错误处理（任务不存在）

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/delete-reminder.sh
./scripts/delete-reminder.sh --name "测试任务" --confirm
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/delete-reminder.sh
git commit -m "feat: add delete-reminder.sh script"
```

---

## Task 11: 创建 Reminders 基础脚本 - search-reminders.sh

**Files:**
- Create: `skills/apple-productivity/scripts/search-reminders.sh`

**Step 1: 创建脚本**

创建搜索任务的脚本，支持：
- 关键词搜索
- 按列表过滤
- 显示匹配结果

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/search-reminders.sh
./scripts/search-reminders.sh --query "测试"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/search-reminders.sh
git commit -m "feat: add search-reminders.sh script"
```

---

## Task 12: 创建 Calendar 基础脚本 - create-event.sh

**Files:**
- Create: `skills/apple-productivity/scripts/create-event.sh`

**Step 1: 创建脚本**

创建日历事件的脚本，支持：
- 创建事件（标题、日历、开始时间、结束时间）
- 设置地点
- 添加参与者
- 自然语言解析

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/create-event.sh
./scripts/create-event.sh --title "测试会议" --start "2026-02-28 14:00" --end "2026-02-28 15:00"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/create-event.sh
git commit -m "feat: add create-event.sh script"
```

---

## Task 13: 创建 Calendar 基础脚本 - list-events.sh

**Files:**
- Create: `skills/apple-productivity/scripts/list-events.sh`

**Step 1: 创建脚本**

创建列出日历事件的脚本，支持：
- 按日期列出
- 按范围列出（day/week/month）
- 按日历过滤
- 显示事件详情

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/list-events.sh
./scripts/list-events.sh --date "2026-02-28"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/list-events.sh
git commit -m "feat: add list-events.sh script"
```

---

## Task 14: 创建 Calendar 基础脚本 - get-event.sh

**Files:**
- Create: `skills/apple-productivity/scripts/get-event.sh`

**Step 1: 创建脚本**

创建获取单个事件详情的脚本，支持：
- 按标题和日期查找
- 显示完整信息（标题、时间、地点、参与者、备注）

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/get-event.sh
./scripts/get-event.sh --title "测试会议" --date "2026-02-28"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/get-event.sh
git commit -m "feat: add get-event.sh script"
```

---

## Task 15: 创建 Calendar 基础脚本 - update-event.sh

**Files:**
- Create: `skills/apple-productivity/scripts/update-event.sh`

**Step 1: 创建脚本**

创建更新事件的脚本，支持：
- 更新标题
- 更新时间
- 更新地点
- 更新参与者

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/update-event.sh
./scripts/update-event.sh --title "测试会议" --new-title "新会议"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/update-event.sh
git commit -m "feat: add update-event.sh script"
```

---

## Task 16: 创建 Calendar 基础脚本 - delete-event.sh

**Files:**
- Create: `skills/apple-productivity/scripts/delete-event.sh`

**Step 1: 创建脚本**

创建删除事件的脚本，支持：
- 按标题和日期删除
- 确认提示
- 错误处理

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/delete-event.sh
./scripts/delete-event.sh --title "测试会议" --date "2026-02-28" --confirm
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/delete-event.sh
git commit -m "feat: add delete-event.sh script"
```

---

## Task 17: 创建 Calendar 高级脚本 - find-free-time.sh

**Files:**
- Create: `skills/apple-productivity/scripts/find-free-time.sh`

**Step 1: 创建脚本**

创建查找空闲时间的脚本，支持：
- 指定日期
- 指定时长
- 返回可用的时间段

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/find-free-time.sh
./scripts/find-free-time.sh --date "2026-02-28" --duration 60
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/find-free-time.sh
git commit -m "feat: add find-free-time.sh script"
```

---

## Task 18: 创建 Calendar 高级脚本 - suggest-meeting-time.sh

**Files:**
- Create: `skills/apple-productivity/scripts/suggest-meeting-time.sh`

**Step 1: 创建脚本**

创建建议会议时间的脚本，支持：
- 指定参与者
- 指定日期范围
- 返回推荐的会议时间

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/suggest-meeting-time.sh
./scripts/suggest-meeting-time.sh --duration 60 --range "next-week"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/suggest-meeting-time.sh
git commit -m "feat: add suggest-meeting-time.sh script"
```

---

## Task 19: 创建跨模块整合脚本 - reminder-to-event.sh

**Files:**
- Create: `skills/apple-productivity/scripts/reminder-to-event.sh`

**Step 1: 创建脚本**

创建任务转日程的脚本，支持：
- 按名称查找任务
- 创建日历事件（使用任务截止时间或指定时间）
- 设置事件时长

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/reminder-to-event.sh
./scripts/reminder-to-event.sh --name "任务名称" --duration 60
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/reminder-to-event.sh
git commit -m "feat: add reminder-to-event.sh integration script"
```

---

## Task 20: 创建跨模块整合脚本 - event-to-reminder.sh

**Files:**
- Create: `skills/apple-productivity/scripts/event-to-reminder.sh`

**Step 1: 创建脚本**

创建日程转任务的脚本，支持：
- 按标题查找事件
- 创建会前准备任务
- 创建会后跟进任务

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/event-to-reminder.sh
./scripts/event-to-reminder.sh --title "会议" --create-prep-task true
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/event-to-reminder.sh
git commit -m "feat: add event-to-reminder.sh integration script"
```

---

## Task 21: 创建跨模块整合脚本 - sync-view.sh

**Files:**
- Create: `skills/apple-productivity/scripts/sync-view.sh`

**Step 1: 创建脚本**

创建同步视图脚本，支持：
- 显示指定日期的事件和任务
- 统一格式化输出
- 高亮显示关联项

**Step 2: 添加执行权限并测试**

```bash
chmod +x skills/apple-productivity/scripts/sync-view.sh
./scripts/sync-view.sh --date "2026-02-28"
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/scripts/sync-view.sh
git commit -m "feat: add sync-view.sh integration script"
```

---

## Task 22: 创建 SKILL.md 技能文档

**Files:**
- Create: `skills/apple-productivity/SKILL.md`

**Step 1: 创建技能文档**

创建完整的技能说明文档，包含：
- 技能描述
- 可用命令列表
- 配置说明
- 使用示例
- AppleScript 参考

**Step 2: 提交**

```bash
git add skills/apple-productivity/SKILL.md
git commit -m "docs: add SKILL.md documentation"
```

---

## Task 23: 创建模板文件

**Files:**
- Create: `skills/apple-productivity/templates/reminder-template.md`
- Create: `skills/apple-productivity/templates/event-template.md`

**Step 1: 创建提醒模板**

```markdown
---
类型：提醒事项
优先级：中
截止时间：YYYY-MM-DD HH:MM
列表：提醒事项
---

# 任务名称

## 描述


## 子任务

- [ ] 子任务 1
- [ ] 子任务 2

## 备注

```

**Step 2: 创建事件模板**

```markdown
---
类型：日历事件
开始时间：YYYY-MM-DD HH:MM
结束时间：YYYY-MM-DD HH:MM
日历：日历
地点：
参与者：
---

# 事件名称

## 议程


## 会前准备

- [ ] 准备材料

## 会后跟进

- [ ] 发送会议纪要
```

**Step 3: 提交**

```bash
git add skills/apple-productivity/templates/
git commit -m "docs: add reminder and event templates"
```

---

## Task 24: 集成测试

**Files:**
- Modify: 所有脚本

**Step 1: 测试 Reminders 完整流程**

```bash
cd skills/apple-productivity

# 创建任务
./scripts/create-reminder.sh --name "集成测试任务" --due "2026-02-28 15:00" --priority 2

# 列出任务
./scripts/list-reminders.sh --status "pending"

# 获取任务详情
./scripts/get-reminder.sh --name "集成测试任务"

# 更新任务
./scripts/update-reminder.sh --name "集成测试任务" --priority 3

# 完成任务
./scripts/complete-reminder.sh --name "集成测试任务"

# 搜索任务
./scripts/search-reminders.sh --query "集成测试"

# 删除任务
./scripts/delete-reminder.sh --name "集成测试任务" --confirm
```

**Step 2: 测试 Calendar 完整流程**

```bash
# 创建事件
./scripts/create-event.sh --title "集成测试会议" --start "2026-02-28 14:00" --end "2026-02-28 15:00" --location "办公室"

# 列出事件
./scripts/list-events.sh --date "2026-02-28"

# 获取事件详情
./scripts/get-event.sh --title "集成测试会议" --date "2026-02-28"

# 更新事件
./scripts/update-event.sh --title "集成测试会议" --new-title "新会议名称"

# 删除事件
./scripts/delete-event.sh --title "新会议名称" --date "2026-02-28" --confirm
```

**Step 3: 测试跨模块整合**

```bash
# 创建任务并转为事件
./scripts/create-reminder.sh --name "任务转事件测试" --due "2026-03-01 10:00"
./scripts/reminder-to-event.sh --name "任务转事件测试" --duration 60

# 创建事件并转为任务
./scripts/create-event.sh --title "会议转任务测试" --start "2026-03-02 14:00" --end "2026-03-02 15:00"
./scripts/event-to-reminder.sh --title "会议转任务测试" --create-prep-task true

# 同步视图
./scripts/sync-view.sh --date "2026-03-01"
```

**Step 4: 提交测试结果**

```bash
git commit --allow-empty -m "test: complete integration testing"
```

---

## Task 25: 更新主 README.md

**Files:**
- Modify: `README.md`

**Step 1: 更新规划中模块部分**

将原来的"规划中模块"更新为"已实现模块"，添加 apple-productivity 的说明。

**Step 2: 提交**

```bash
git add README.md
git commit -m "docs: update README with apple-productivity module"
```

---

## 完成检查

**交付物清单：**
- [ ] `skills/apple-productivity/SKILL.md`
- [ ] `skills/apple-productivity/.local.md`
- [ ] `skills/apple-productivity/scripts/` (15+ 脚本)
- [ ] `skills/apple-productivity/references/` (2 个参考文档)
- [ ] `skills/apple-productivity/templates/` (2 个模板)
- [ ] 所有脚本可执行权限
- [ ] 集成测试通过
- [ ] README 更新

---

**测试通过标准：**
1. 所有 Reminders CRUD 操作正常工作
2. 所有 Calendar CRUD 操作正常工作
3. 跨模块整合功能正常工作
4. 自然语言解析能正确提取时间和任务/事件信息
5. 错误处理正确（任务/事件不存在、权限不足等）
