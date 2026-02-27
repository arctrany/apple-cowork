---
name: apple-notes
description: This skill should be used when the user asks to "read my notes", "list notes", "search notes", "create a note", "update a note", "get note content", or mentions Apple Notes access. Provides AppleScript-based Apple Notes integration for any CLI tool.
version: 0.1.0
---

# Apple Notes Integration Skill

## Purpose

Provide seamless access to Apple Notes on macOS using AppleScript. This skill enables any CLI tool (Claude Code, iflow, qwen, gemini, etc.) to read, search, create, and update notes in the Apple Notes application.

## Available Commands

All commands are executed via the scripts in `scripts/`:

| Command | Description |
|---------|-------------|
| `scripts/list-notes.sh` | List all notes in a folder/account |
| `scripts/get-note.sh` | Get full content of a specific note |
| `scripts/search-notes.sh` | Search notes by keyword |
| `scripts/create-note.sh` | Create a new note |
| `scripts/update-note.sh` | Update an existing note |

## Configuration

Load configuration from `.local.md` file:

```yaml
default_account: 谷歌
default_folder: Notes
```

## Usage Patterns

### List Notes

```bash
scripts/list-notes.sh [--account "账户名"] [--folder "文件夹名"]
```

### Get Note Content

```bash
scripts/get-note.sh --name "笔记名称" [--account "账户名"] [--folder "文件夹名"]
```

### Search Notes

```bash
scripts/search-notes.sh --query "关键词" [--account "账户名"]
```

### Create Note

```bash
scripts/create-note.sh --name "笔记名称" --body "笔记内容" [--folder "文件夹名"]
```

### Update Note

```bash
scripts/update-note.sh --name "笔记名称" --body "新内容"
```

## AppleScript Reference

For custom queries, use these AppleScript patterns:

```applescript
-- Get all accounts
tell application "Notes" to get name of every account

-- Get all folders in account
tell application "Notes" to get name of every folder of account "账户名"

-- Get all notes in folder
tell application "Notes" to get name of every note of folder "文件夹名" of account "账户名"

-- Get note body
tell application "Notes" to get body of note "笔记名" of folder "文件夹名" of account "账户名"
```

## Additional Resources

- **`references/applescript-guide.md`** - Detailed AppleScript patterns and examples
- **`scripts/`** - Executable shell scripts for common operations

## Cross-CLI Usage

This skill is designed to work with any CLI that can:
1. Execute shell scripts
2. Read configuration from `.local.md` files

### For Claude Code
Scripts are automatically available via Bash tool.

### For Other CLIs (iflow, qwen, gemini)
Copy the `scripts/` directory and call scripts directly:

```bash
./scripts/list-notes.sh
./scripts/get-note.sh --name "my note"
```
