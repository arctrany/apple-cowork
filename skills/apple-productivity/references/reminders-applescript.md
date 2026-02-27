# Reminders AppleScript 参考指南

## 基本操作

### 获取所有账户

```applescript
tell application "Reminders"
    get name of every account
end tell
```

### 获取账户中的所有列表

```applescript
tell application "Reminders"
    get name of every list of account "账户名"
end tell
```

### 获取列表中的所有提醒

```applescript
tell application "Reminders"
    get name of every reminder of list "列表名" of account "账户名"
end tell
```

## 创建操作

### 创建新提醒

```applescript
tell application "Reminders"
    set newList to make new reminder at end of reminders of list "列表名" with properties {name:"提醒名称"}
    get id of newList
end tell
```

### 创建带详细信息的提醒

```applescript
tell application "Reminders"
    set targetList to list "列表名" of account "账户名"
    set newReminder to make new reminder at end of reminders of targetList with properties {name:"提醒名称", body:"备注内容"}

    -- 设置优先级 (0=无，1=低，2=中，3=高)
    set priority of newReminder to 2

    -- 设置截止时间
    set due date of newReminder to date "2026-02-28 15:00:00"

    -- 设置提醒时间
    set reminder date of newReminder to date "2026-02-28 14:00:00"

    get id of newReminder
end tell
```

### 创建子任务

```applescript
tell application "Reminders"
    set parentReminder to reminder "父任务名" of list "列表名"
    set childReminder to make new reminder at end of reminders of list "列表名" with properties {name:"子任务名"}

    -- 将子任务附加到父任务（需要 macOS 10.11+）
    -- 注意：AppleScript 不直接支持设置父任务，需要通过 UI Scripting
end tell
```

## 读取操作

### 获取单个提醒的完整内容

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "列表名" of account "账户名"
    return {
        name:name of r,
        body:body of r,
        priority:priority of r,
        due date:due date of r,
        reminder date:reminder date of r,
        completed:completed of r
    }
end tell
```

### 获取提醒的 URL（深度链接）

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "列表名" of account "账户名"
    get id of r  -- 用于构造 x-apple-reminder:// 链接
end tell
```

### 获取所有待完成提醒

```applescript
tell application "Reminders"
    set pendingReminders to every reminder of list "列表名" whose completed is false
    repeat with r in pendingReminders
        log "任务：" & name of r
        log "截止时间：" & (due date of r)
    end repeat
end tell
```

### 获取所有已完成提醒

```applescript
tell application "Reminders"
    set completedReminders to every reminder of list "列表名" whose completed is true
    repeat with r in completedReminders
        log "已完成：" & name of r
    end repeat
end tell
```

## 更新操作

### 更新提醒名称

```applescript
tell application "Reminders"
    set r to reminder "旧名称" of list "列表名"
    set name of r to "新名称"
end tell
```

### 更新提醒详细信息

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "列表名"
    set body of r to "新备注"
    set priority of r to 3  -- 高优先级
    set due date of r to date "2026-03-01 18:00:00"
end tell
```

### 移动提醒到另一个列表

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "旧列表"
    set targetList to list "新列表" of account "账户名"
    move r to targetList
end tell
```

### 标记为已完成

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "列表名"
    set completed of r to true
end tell
```

### 切换完成状态

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "列表名"
    set completed of r to not (completed of r)
end tell
```

## 删除操作

### 删除提醒

```applescript
tell application "Reminders"
    delete reminder "提醒名称" of list "列表名"
end tell
```

## 搜索操作

### 在账户中搜索提醒

```applescript
tell application "Reminders"
    set found to search for "关键词" in account "账户名"
    repeat with r in found
        log name of r & " (列表：" & (name of container of r) & ")"
    end repeat
end tell
```

### 在特定列表中搜索

```applescript
tell application "Reminders"
    set found to search for "关键词" in list "列表名" of account "账户名"
    repeat with r in found
        log name of r
    end repeat
end tell
```

## 列表管理

### 创建新列表

```applescript
tell application "Reminders"
    make new list at end of lists with properties {name:"新列表名"}
end tell
```

### 删除列表

```applescript
tell application "Reminders"
    delete list "列表名" of account "账户名"
end tell
```

### 重命名列表

```applescript
tell application "Reminders"
    set name of list "旧名称" of account "账户名" to "新名称"
end tell
```

## 高级操作

### 遍历所有提醒

```applescript
tell application "Reminders"
    repeat with r in every reminder of list "列表名" of account "账户名"
        log "=== " & name of r & " ==="
        log "备注：" & (body of r)
        log "优先级：" & (priority of r)
        log "截止时间：" & (due date of r)
        log "完成状态：" & (completed of r)
    end repeat
end tell
```

### 检查提醒是否存在

```applescript
tell application "Reminders"
    try
        set r to reminder "提醒名称" of list "列表名"
        log "提醒存在"
    on error
        log "提醒不存在"
    end try
end tell
```

### 获取提醒的创建/修改时间

```applescript
tell application "Reminders"
    set r to reminder "提醒名称" of list "列表名"
    -- 注意：Reminders AppleScript 字典不直接提供 creation/modification date
    -- 需要通过其他方式获取
end tell
```

### 按日期范围过滤提醒

```applescript
tell application "Reminders"
    set startDate to date "2026-02-01 00:00:00"
    set endDate to date "2026-02-28 23:59:59"

    set filteredReminders to (every reminder of list "列表名" whose due date ≥ startDate and due date ≤ endDate)

    repeat with r in filteredReminders
        log name of r & " - " & (due date of r)
    end repeat
end tell
```

## 从 Shell 调用 AppleScript

### 单行调用

```bash
osascript -e 'tell application "Reminders" to get name of every reminder'
```

### 多行调用（HEREDOC）

```bash
osascript <<EOF
tell application "Reminders"
    set r to reminder "我的任务" of list "提醒事项"
    get body of r
end tell
EOF
```

### 带参数调用

```bash
REMINDER_NAME="任务名称"
DUE_DATE="2026-02-28 15:00:00"

osascript <<EOF
tell application "Reminders"
    set targetList to list "提醒事项" of account "iCloud"
    set newReminder to make new reminder at end of reminders of targetList with properties {name:"$REMINDER_NAME"}
    set due date of newReminder to date "$DUE_DATE"
end tell
EOF
```

### 处理特殊字符

当内容包含引号等特殊字符时，需要转义：

```bash
NOTE_BODY="这是包含\"引号\"的内容"
osascript <<EOF
tell application "Reminders"
    set newReminder to make new reminder with properties {name:"标题", body:"$NOTE_BODY"}
end tell
EOF
```

## 错误处理

```applescript
tell application "Reminders"
    try
        -- 操作代码
        get body of reminder "不存在的提醒" of list "列表名"
    on error errMsg number errNum
        log "错误号：" & errNum
        log "错误信息：" & errMsg

        -- 常见错误号
        -- -1728: 提醒不存在
        -- -1700: 参数错误
        -- -1712: 超时
    end try
end tell
```

## 常见问题

### Q: 如何获取提醒的唯一标识符？

```applescript
tell application "Reminders"
    get id of reminder "提醒名" of list "列表名"
end tell
```

### Q: 如何打开特定提醒？

```applescript
tell application "Reminders"
    show reminder "提醒名" of list "列表名"
end tell
```

### Q: 如何获取所有账户的所有列表？

```applescript
tell application "Reminders"
    repeat with acc in every account
        log "账户：" & name of acc
        repeat with lst in every list of acc
            log "  列表：" & name of lst
        end repeat
    end repeat
end tell
```

### Q: 如何获取提醒所在的列表？

```applescript
tell application "Reminders"
    set r to reminder "提醒名"
    set containerList to container of r  -- 返回 list 对象
    log name of containerList
end tell
```

## 常见错误号

| 错误号 | 描述 |
|--------|------|
| -1728 | 提醒/列表不存在 |
| -1700 | 参数错误 |
| -1712 | 超时 |
| -1713 | 用户取消 |
| -1714 | 访问被拒绝（需要权限） |

## 权限说明

macOS Catalina (10.15) 及更高版本需要授予应用访问 Reminders 的权限：

1. 系统偏好设置 → 隐私与安全性 →  reminders
2. 确保终端应用或脚本编辑器已勾选
