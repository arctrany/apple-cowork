---
name: apple-productivity
description: This skill should be used when the user asks to "create a reminder", "list my tasks", "schedule a meeting", "check my calendar", "find free time", "convert task to event", or mentions Apple Reminders or Calendar access. Provides AppleScript-based integration for task and日程管理.
version: 0.1.0
---

# Apple Productivity Integration Skill

## Purpose

提供无缝的 Apple Reminders 和 Apple Calendar 集成，支持：
- 任务管理（创建、读取、更新、删除、完成）
- 日程管理（创建、读取、更新、删除事件）
- 空闲时间查询和会议建议
- 跨模块整合（任务↔日程双向转换）
- 自然语言解析

## Available Commands

所有命令通过 `scripts/` 目录下的脚本执行：

### Reminders 相关命令

| 命令 | 描述 |
|------|------|
| `scripts/create-reminder.sh` | 创建新的提醒事项 |
| `scripts/list-reminders.sh` | 列出任务 |
| `scripts/get-reminder.sh` | 获取任务详情 |
| `scripts/update-reminder.sh` | 更新任务 |
| `scripts/complete-reminder.sh` | 完成/取消完成任务 |
| `scripts/delete-reminder.sh` | 删除任务 |
| `scripts/search-reminders.sh` | 搜索任务 |

### Calendar 相关命令

| 命令 | 描述 |
|------|------|
| `scripts/create-event.sh` | 创建日历事件 |
| `scripts/list-events.sh` | 列出事件 |
| `scripts/get-event.sh` | 获取事件详情 |
| `scripts/update-event.sh` | 更新事件 |
| `scripts/delete-event.sh` | 删除事件 |
| `scripts/find-free-time.sh` | 查找空闲时间 |
| `scripts/suggest-meeting-time.sh` | 建议会议时间 |

### 跨模块整合命令

| 命令 | 描述 |
|------|------|
| `scripts/reminder-to-event.sh` | 将任务转换为日历事件 |
| `scripts/event-to-reminder.sh` | 从会议创建关联任务 |
| `scripts/sync-view.sh` | 同步视图（任务 + 事件） |

## Configuration

从 `.local.md` 文件加载配置：

```markdown
---
# 默认账户设置
default_account: iCloud

# Reminders 默认设置
default_reminder_list: 提醒事项
default_reminder_priority: 0

# Calendar 默认设置
default_calendar: 日历
default_event_duration: 60

# 跨模块整合设置
enable_cross_module: true
auto_create_reminders_from_events: false
```

## Usage Patterns

### Reminders 使用示例

#### 创建任务

```bash
# 基本创建
./scripts/create-reminder.sh --name "完成项目报告" --due "2026-02-28 15:00" --priority 2

# 自然语言创建
./scripts/create-reminder.sh --parse "明天下午 3 点完成项目报告"

# 带备注
./scripts/create-reminder.sh --name "买咖啡" --note "需要：美式、咖啡豆"
```

#### 列出任务

```bash
# 列出所有任务
./scripts/list-reminders.sh

# 只列出待完成任务
./scripts/list-reminders.sh --status pending

# 只列出已完成任务
./scripts/list-reminders.sh --status completed
```

#### 获取任务详情

```bash
./scripts/get-reminder.sh --name "完成项目报告"
```

#### 更新任务

```bash
# 更新截止时间
./scripts/update-reminder.sh --name "完成项目报告" --due "2026-02-28 18:00"

# 更新优先级
./scripts/update-reminder.sh --name "完成项目报告" --priority 3
```

#### 完成任务

```bash
# 切换完成状态
./scripts/complete-reminder.sh --name "完成项目报告" --toggle

# 标记为已完成
./scripts/complete-reminder.sh --name "完成项目报告" --complete

# 标记为未完成
./scripts/complete-reminder.sh --name "完成项目报告" --uncomplete
```

#### 搜索任务

```bash
./scripts/search-reminders.sh --query "项目"
```

#### 删除任务

```bash
./scripts/delete-reminder.sh --name "完成项目报告" --confirm
```

### Calendar 使用示例

#### 创建事件

```bash
# 基本创建
./scripts/create-event.sh --title "项目会议" --start "2026-02-28 14:00" --end "2026-02-28 15:00"

# 自然语言创建
./scripts/create-event.sh --parse "明天下午 2 点到 3 点在办公室开项目会议"

# 带地点和备注
./scripts/create-event.sh --title "项目会议" --start "2026-02-28 14:00" --end "2026-02-28 15:00" --location "办公室" --note "讨论项目进度"
```

#### 列出事件

```bash
# 列出今天事件
./scripts/list-events.sh --date "2026-02-28"

# 列出本周事件
./scripts/list-events.sh --range week

# 列出本月事件
./scripts/list-events.sh --range month
```

#### 获取事件详情

```bash
./scripts/get-event.sh --title "项目会议" --date "2026-02-28"
```

#### 更新事件

```bash
# 更新标题
./scripts/update-event.sh --title "项目会议" --new-title "新项目启动会议"

# 更新时间
./scripts/update-event.sh --title "项目会议" --new-start "2026-02-28 15:00" --new-end "2026-02-28 16:00"
```

#### 删除事件

```bash
./scripts/delete-event.sh --title "项目会议" --date "2026-02-28" --confirm
```

#### 查找空闲时间

```bash
./scripts/find-free-time.sh --date "2026-02-28" --duration 60
```

#### 建议会议时间

```bash
./scripts/suggest-meeting-time.sh --duration 60 --range week
```

### 跨模块整合示例

#### 任务转日程

```bash
# 使用任务的截止时间创建事件
./scripts/reminder-to-event.sh --name "完成项目报告" --use-due-date --duration 60
```

#### 日程转任务

```bash
# 创建会前准备和会后跟进任务
./scripts/event-to-reminder.sh --title "项目会议" --create-prep-task --create-followup-task
```

#### 同步视图

```bash
./scripts/sync-view.sh --date "2026-02-28"
```

## AppleScript Reference

### Reminders 基础操作

```applescript
-- 创建提醒
tell application "Reminders"
    set targetList to list "提醒事项" of account "iCloud"
    set newReminder to make new reminder at end of reminders of targetList with properties {name:"任务名"}
end tell

-- 获取提醒
tell application "Reminders"
    set r to reminder "任务名"
    get {name, body, due date, priority, completed} of r
end tell

-- 完成提醒
tell application "Reminders"
    set completed of reminder "任务名" to true
end tell
```

### Calendar 基础操作

```applescript
-- 创建事件
tell application "Calendar"
    set targetCalendar to calendar "日历"
    set newEvent to make new event at end of events of targetCalendar with properties {
        summary:"会议",
        start date:date "2026-02-28 14:00:00",
        end date:date "2026-02-28 15:00:00"
    }
end tell

-- 获取事件
tell application "Calendar"
    set todayEvents to every event of calendar "日历" whose start date ≥ (current date)
end tell
```

## Error Handling

### 常见错误场景

| 错误 | 处理方式 |
|------|----------|
| 任务/事件不存在 | 返回错误信息，建议检查名称 |
| 列表/日历不存在 | 返回可用列表/日历供选择 |
| 时间冲突 | 显示冲突事件并建议替代时间 |
| 权限不足 | 引导用户开启系统权限 |

### 错误码

| 错误码 | 描述 |
|--------|------|
| 0 | 成功 |
| 1 | 一般错误 |
| 10 | 账户不存在 |
| 11 | 列表/日历不存在 |
| 20 | 任务/事件不存在 |
| 30 | 时间冲突 |
| 40 | 权限不足 |
| 50 | 参数错误 |

## Cross-CLI Usage

此技能设计用于任何可以执行 shell 脚本的 CLI 工具。

### For Claude Code

脚本通过 Bash 工具自动可用。

### For Other CLIs

复制 `scripts/` 目录并直接调用脚本：

```bash
./scripts/create-reminder.sh --name "任务名"
./scripts/list-events.sh --date "2026-02-28"
```

## Permissions

macOS Catalina (10.15) 及更高版本需要授予应用访问 Reminders 和 Calendar 的权限：

1. 系统偏好设置 → 隐私与安全性 → Reminders
2. 系统偏好设置 → 隐私与安全性 → 日历
3. 确保终端应用或脚本编辑器已勾选
