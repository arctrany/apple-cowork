# Apple Productivity 技能设计文档

**日期：** 2026-02-27
**状态：** 已批准
**作者：** AI Assistant

---

## 1. 项目概述

### 1.1 愿景
建立一套完整的工具链，让 AI 能够无缝与 Apple 生态中的 Reminders 和 Calendar 进行交互，实现任务管理、日程安排和跨模块整合的自动化。

### 1.2 范围
本技能整合 Apple Reminders 和 Apple Calendar 两个模块，提供：
- 任务和日程的 CRUD 操作
- 自然语言解析能力
- 跨模块整合功能（任务↔日程双向转换）

---

## 2. 技术架构

### 2.1 技术栈选择
| 组件 | 技术 | 理由 |
|------|------|------|
| 核心交互 | AppleScript | 成熟稳定，与现有 apple-notes 技能一致 |
| 执行层 | Shell 脚本 | 与现有技能保持一致，便于维护 |
| 配置管理 | `.local.md` YAML 配置 | 统一配置文件，支持默认值设置 |

### 2.2 技能结构
```
skills/apple-productivity/
├── SKILL.md                 # 技能描述和使用说明
├── .local.md                # 配置文件（账户、默认列表等）
├── scripts/
│   # Reminders 相关脚本
│   ├── create-reminder.sh
│   ├── get-reminder.sh
│   ├── update-reminder.sh
│   ├── delete-reminder.sh
│   ├── list-reminders.sh
│   ├── complete-reminder.sh
│   ├── search-reminders.sh
│   # Calendar 相关脚本
│   ├── create-event.sh
│   ├── get-event.sh
│   ├── update-event.sh
│   ├── delete-event.sh
│   ├── list-events.sh
│   ├── find-free-time.sh
│   ├── suggest-meeting-time.sh
│   # 跨模块整合脚本
│   ├── reminder-to-event.sh
│   ├── event-to-reminder.sh
│   └── sync-view.sh
├── references/
│   ├── reminders-applescript.md   # Reminders AppleScript 参考
│   └── calendar-applescript.md    # Calendar AppleScript 参考
└── templates/
    ├── reminder-template.md
    └── event-template.md
```

---

## 3. 功能清单

### 3.1 Reminders 模块

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 创建任务 | 创建新的提醒事项，支持设置列表、优先级、截止时间和提醒 | P0 |
| 读取任务 | 获取单个或多个任务的详细信息 | P0 |
| 更新任务 | 修改任务的属性（标题、笔记、截止时间、优先级等） | P0 |
| 删除任务 | 删除指定的提醒事项 | P0 |
| 完成任务 | 标记任务为已完成/未完成 | P0 |
| 列表管理 | 创建、删除、切换提醒事项列表 | P1 |
| 子任务 | 创建和管理子任务 | P1 |
| 搜索任务 | 按关键词、日期、列表等条件搜索任务 | P1 |
| 自然语言解析 | 解析自然语言输入自动提取任务名、时间、优先级等信息 | P1 |

### 3.2 Calendar 模块

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 创建事件 | 创建新的日历事件，支持设置日历、时间、地点、参与者 | P0 |
| 读取事件 | 获取单日/周/月的事件列表或单个事件详情 | P0 |
| 更新事件 | 修改事件的属性（时间、标题、地点、参与者等） | P0 |
| 删除事件 | 删除指定的日历事件 | P0 |
| 空闲时间查询 | 查询指定时间段的空闲时间 | P1 |
| 智能安排建议 | 根据参与者空闲时间推荐会议时间 | P1 |
| 冲突检测 | 检测时间冲突并提供解决方案 | P1 |
| 自然语言解析 | 解析自然语言输入自动提取事件名、时间、地点等信息 | P1 |

### 3.3 跨模块整合

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 任务转日程 | 将 Reminders 任务转换为 Calendar 时间块事件 | P1 |
| 日程转任务 | 从 Calendar 会议自动创建 Reminders 任务（会前准备、会后跟进） | P1 |
| 双向同步视图 | 统一视图显示关联的任务和日程 | P2 |
| 智能提醒 | 根据日历空闲时间推荐任务执行时间，会议前自动提醒 | P2 |

---

## 4. 配置设计

### 4.1 配置文件格式
位置：`skills/apple-productivity/.local.md`

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
auto_create_reminders_from_events: false  # 是否自动从会议创建任务
```

---

## 5. 接口设计

### 5.1 Reminders 脚本接口

```bash
# 创建任务
./scripts/create-reminder.sh --name "任务名称" --list "列表名" --due "2026-02-28 15:00" --priority 2 --note "备注"

# 自然语言创建
./scripts/create-reminder.sh --parse "明天下午 3 点完成项目报告"

# 获取任务
./scripts/get-reminder.sh --name "任务名称"

# 列出任务
./scripts/list-reminders.sh --list "列表名" --status "all|pending|completed"

# 更新任务
./scripts/update-reminder.sh --name "任务名称" --due "新截止时间" --priority 3

# 完成任务
./scripts/complete-reminder.sh --name "任务名称" --toggle

# 删除任务
./scripts/delete-reminder.sh --name "任务名称" --confirm

# 搜索任务
./scripts/search-reminders.sh --query "关键词" --in "列表名"
```

### 5.2 Calendar 脚本接口

```bash
# 创建事件
./scripts/create-event.sh --title "会议" --calendar "日历" --start "2026-02-28 14:00" --end "2026-02-28 15:00" --location "办公室" --participants "张三，李四"

# 自然语言创建
./scripts/create-event.sh --parse "明天下午 2 点到 3 点在办公室开项目会议，参加人张三李四"

# 列出事件
./scripts/list-events.sh --calendar "日历" --date "2026-02-28"
./scripts/list-events.sh --calendar "日历" --range "week"

# 获取事件详情
./scripts/get-event.sh --title "会议" --date "2026-02-28"

# 更新事件
./scripts/update-event.sh --title "会议" --new-title "新会议" --new-time "2026-02-28 15:00-16:00"

# 删除事件
./scripts/delete-event.sh --title "会议" --date "2026-02-28" --confirm

# 查找空闲时间
./scripts/find-free-time.sh --duration 60 --date "2026-02-28"

# 建议会议时间
./scripts/suggest-meeting-time.sh --duration 60 --participants "张三，李四" --range "next-week"
```

### 5.3 跨模块整合接口

```bash
# 任务转日程
./scripts/reminder-to-event.sh --name "任务名称" --duration 60

# 日程转任务
./scripts/event-to-reminder.sh --title "会议" --create-prep-task true --create-followup-task true

# 同步视图
./scripts/sync-view.sh --date "2026-02-28" --show-reminders true
```

---

## 6. AppleScript 实现参考

### 6.1 Reminders AppleScript

```applescript
-- 创建提醒
tell application "Reminders"
    set newList to make new reminder with properties {name:"任务名", body:"备注", due date:date "2026-02-28 15:00", priority:2}
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

-- 搜索提醒
tell application "Reminders"
    set found to search for "关键词"
    repeat with r in found
        log name of r
    end repeat
end tell
```

### 6.2 Calendar AppleScript

```applescript
-- 创建事件
tell application "Calendar"
    set newEvent to make new event at end of events of calendar "日历" with properties {summary:"会议", start date:date "2026-02-28 14:00", end date:date "2026-02-28 15:00", location:"办公室"}
end tell

-- 获取事件
tell application "Calendar"
    set todayEvents to every event of calendar "日历" whose start date ≥ (current date)
    repeat with e in todayEvents
        log summary of e
    end repeat
end tell

-- 查找空闲时间
-- 需要遍历事件找出空隙
```

---

## 7. 错误处理

### 7.1 常见错误场景
| 错误 | 处理方式 |
|------|----------|
| 账户不存在 | 返回可用账户列表供用户选择 |
| 列表/日历不存在 | 询问是否创建新列表/日历 |
| 任务/事件不存在 | 返回搜索结果或建议相似项 |
| 时间冲突 | 显示冲突事件并建议替代时间 |
| 权限不足 | 引导用户开启系统权限（系统偏好设置→隐私） |

### 7.2 错误码设计
```bash
0   # 成功
1   # 一般错误
10  # 账户不存在
11  # 列表/日历不存在
20  # 任务/事件不存在
30  # 时间冲突
40  # 权限不足
50  # 参数错误
```

---

## 8. 测试策略

### 8.1 单元测试
- 每个脚本的独立功能测试
- AppleScript 核心逻辑测试

### 8.2 集成测试
- Reminders 和 Calendar 的端到端测试
- 跨模块整合流程测试

### 8.3 手动测试清单
- [ ] 创建/读取/更新/删除任务
- [ ] 创建/读取/更新/删除事件
- [ ] 自然语言解析准确性
- [ ] 任务转日程流程
- [ ] 日程转任务流程
- [ ] 空闲时间查询
- [ ] 智能时间建议

---

## 9. 交付物

1. **技能文件**
   - `SKILL.md` - 技能描述和使用说明
   - `.local.md` - 配置模板

2. **脚本文件**
   - 15+ 可执行 Shell 脚本

3. **参考文档**
   - `references/reminders-applescript.md`
   - `references/calendar-applescript.md`

4. **模板文件**
   - `templates/reminder-template.md`
   - `templates/event-template.md`

---

## 10. 后续迭代

### 10.1 未来功能
- 与 apple-notes 深度整合（笔记中直接创建任务和事件）
- 支持多账户同步
- 周期性任务和事件管理
- 任务/事件导出功能

### 10.2 性能优化
- 批量操作支持
- 缓存机制减少 AppleScript 调用
- 并行处理独立操作
