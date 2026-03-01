---
name: apple-notes
description: 当用户提到「读取笔记」「列出笔记」「搜索笔记」「创建笔记」「更新笔记」「获取笔记内容」或提及 Apple Notes / 备忘录时使用此技能。通过 AppleScript 提供 Apple Notes 集成，适用于任何 CLI 工具。
version: 0.1.0
---

# Apple Notes 集成技能

## 用途

在 macOS 上通过 AppleScript 无缝访问 Apple Notes（备忘录）。此技能使任何 CLI 工具（Claude Code、Cursor、Windsurf 等）都能读取、搜索、创建和更新笔记。

## 可用命令

所有命令通过 `scripts/` 目录下的脚本执行：

| 命令 | 描述 |
|------|------|
| `scripts/list-notes.sh` | 列出文件夹/账户中的所有笔记 |
| `scripts/get-note.sh` | 获取指定笔记的完整内容 |
| `scripts/search-notes.sh` | 按关键词搜索笔记 |
| `scripts/create-note.sh` | 创建新笔记 |
| `scripts/update-note.sh` | 更新已有笔记 |
| `scripts/get-all-notes.sh` | 获取所有笔记概览 |
| `scripts/note-from-markdown.sh` | 从 Markdown 文件创建笔记 |
| `scripts/note-with-style.sh` | 创建带样式的笔记 |
| `scripts/md-to-notes-html.py` | Markdown 转 Apple Notes HTML |

## 配置

从 `.local.md` 文件加载配置：

```yaml
default_account: iCloud
default_folder: Notes
```

## 使用示例

### 列出笔记

```bash
scripts/list-notes.sh [--account "账户名"] [--folder "文件夹名"]
```

### 获取笔记内容

```bash
scripts/get-note.sh --name "笔记名称" [--account "账户名"] [--folder "文件夹名"]
```

### 搜索笔记

```bash
scripts/search-notes.sh --query "关键词" [--account "账户名"]
```

### 创建笔记

```bash
scripts/create-note.sh --name "笔记名称" --body "笔记内容" [--folder "文件夹名"]
```

### 更新笔记

```bash
scripts/update-note.sh --name "笔记名称" --body "新内容"
```

## AppleScript 参考

如需自定义查询，使用以下 AppleScript 模式：

```applescript
-- 获取所有账户
tell application "Notes" to get name of every account

-- 获取账户下所有文件夹
tell application "Notes" to get name of every folder of account "账户名"

-- 获取文件夹下所有笔记
tell application "Notes" to get name of every note of folder "文件夹名" of account "账户名"

-- 获取笔记内容
tell application "Notes" to get body of note "笔记名" of folder "文件夹名" of account "账户名"
```

## 补充资源

- **`references/applescript-guide.md`** — AppleScript 详细模式和示例
- **`references/`** — 笔记本管理指南和演示文档
- **`templates/`** — 项目总结、会议记录、Bug 分析模板
- **`scripts/`** — 可执行的 shell 脚本

## 跨 CLI 使用

此技能适用于任何可以执行 shell 脚本的 CLI 工具。

### Claude Code

脚本通过 Bash 工具自动可用。

### 其他 CLI（Cursor、Windsurf、Cline）

复制 `scripts/` 目录并直接调用：

```bash
./scripts/list-notes.sh
./scripts/get-note.sh --name "我的笔记"
```
