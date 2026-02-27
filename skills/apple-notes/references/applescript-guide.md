# AppleScript Apple Notes 参考指南

## 基本操作

### 获取所有账户

```applescript
tell application "Notes"
    get name of every account
end tell
```

### 获取账户中的所有文件夹

```applescript
tell application "Notes"
    get name of every folder of account "账户名"
end tell
```

### 获取文件夹中的所有笔记

```applescript
tell application "Notes"
    get name of every note of folder "文件夹名" of account "账户名"
end tell
```

## 读取操作

### 获取单条笔记的完整内容

```applescript
tell application "Notes"
    get body of note "笔记名" of folder "文件夹名" of account "账户名"
end tell
```

### 获取笔记的 URL（深度链接）

```applescript
tell application "Notes"
    set n to note "笔记名" of folder "文件夹名" of account "账户名"
    get id of n  -- 用于构造 notes:// 链接
end tell
```

## 搜索操作

### 在账户中搜索笔记

```applescript
tell application "Notes"
    set foundNotes to search for "关键词" in account "账户名"
    repeat with n in foundNotes
        log name of n & ": " & body of n
    end repeat
end tell
```

### 在特定文件夹中搜索

```applescript
tell application "Notes"
    set foundNotes to search for "关键词" in folder "文件夹名" of account "账户名"
    repeat with n in foundNotes
        log name of n
    end repeat
end tell
```

## 创建和更新操作

### 创建新笔记

```applescript
tell application "Notes"
    set newNote to create note "笔记标题" in folder "文件夹名" with body "笔记内容"
    get id of newNote
end tell
```

### 更新现有笔记

```applescript
tell application "Notes"
    set existingNote to note "笔记名" of folder "文件夹名"
    set body of existingNote to "新内容"
end tell
```

### 追加内容到笔记

```applescript
tell application "Notes"
    set existingNote to note "笔记名" of folder "文件夹名"
    set body of existingNote to (body of existingNote) & "

追加的内容"
end tell
```

### 删除笔记

```applescript
tell application "Notes"
    delete note "笔记名" of folder "文件夹名"
end tell
```

## 高级操作

### 遍历所有笔记

```applescript
tell application "Notes"
    repeat with n in every note of folder "Notes" of account "iCloud"
        log "=== " & name of n & " ==="
        log body of n
    end repeat
end tell
```

### 获取笔记的创建/修改时间

```applescript
tell application "Notes"
    set n to note "笔记名" of folder "文件夹名"
    log "创建时间：" & (creation date of n)
    log "修改时间：" & (modification date of n)
end tell
```

### 检查笔记是否存在

```applescript
tell application "Notes"
    try
        set n to note "笔记名" of folder "文件夹名"
        log "笔记存在"
    on error
        log "笔记不存在"
    end try
end tell
```

## 从 Shell 调用 AppleScript

### 单行调用

```bash
osascript -e 'tell application "Notes" to get name of every note'
```

### 多行调用（HEREDOC）

```bash
osascript <<EOF
tell application "Notes"
    get body of note "我的笔记" of folder "Notes"
end tell
EOF
```

### 处理特殊字符

当笔记内容包含引号等特殊字符时，需要转义：

```bash
NOTE_BODY="这是包含\"引号\"的内容"
osascript <<EOF
tell application "Notes"
    create note "标题" with body "$NOTE_BODY"
end tell
EOF
```

## 常见问题

### Q: 如何获取笔记的唯一标识符？

```applescript
tell application "Notes"
    get id of note "笔记名" of folder "文件夹名"
end tell
```

### Q: 如何打开特定笔记？

```applescript
tell application "Notes"
    show note "笔记名" of folder "文件夹名"
end tell
```

### Q: 如何获取纯文本内容（去除格式）？

Apple Notes 的 `body` 返回的可能是 RTF 或 HTML 格式。获取纯文本：

```applescript
tell application "Notes"
    set n to note "笔记名"
    -- 使用 plain text 模式
    set noteText to text of n
end tell
```

## 错误处理

```applescript
tell application "Notes"
    try
        -- 操作代码
        get body of note "不存在的笔记"
    on error errMsg number errNum
        log "错误号：" & errNum
        log "错误信息：" & errMsg
    end try
end tell
```

常见错误号：
- `-1728`: 笔记不存在
- `-1700`: 参数错误
- `-1712`: 超时
