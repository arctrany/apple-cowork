# Apple Cowork

> AI + Apple 生态互通方案 — 让任何 AI Code Agent 无缝操作 Apple Notes、Reminders、Calendar

## 支持的 AI Code Agent

| Agent | 接入方式 | 状态 |
|-------|---------|------|
| **Claude Code** | 原生支持，skills 目录自动加载 | ✅ 已验证 |
| **Cursor** | 复制 skills/ 到项目，通过终端执行脚本 | ✅ 兼容 |
| **Windsurf** | 复制 skills/ 到项目，通过终端执行脚本 | ✅ 兼容 |
| **Cline / Roo Code** | 复制 skills/ 到项目，通过终端执行脚本 | ✅ 兼容 |
| **其他 CLI 工具** | 任何能执行 bash 脚本的 AI 工具均可使用 | ✅ 兼容 |

**核心原理：** 所有功能通过标准 shell 脚本 + AppleScript 实现，不依赖任何特定 AI 平台 API。只要你的 AI 工具能执行 bash 命令，就能使用全部功能。

## 安装

### 前置要求

- macOS 10.15 (Catalina) 或更高版本
- Python 3（macOS 自带）
- `pip3 install markdown pyyaml`（仅 Notes 模块 Markdown 转换需要）

### 步骤 1：克隆项目

```bash
git clone https://github.com/arctrany/apple-cowork.git
cd apple-cowork
```

### 步骤 2：授权脚本执行

```bash
chmod +x scripts/*.sh
chmod +x skills/apple-notes/scripts/*.sh
chmod +x skills/apple-productivity/scripts/*.sh
```

### 步骤 3：macOS 权限设置

首次运行脚本时，macOS 会弹出权限请求。你也可以提前在系统设置中授权：

1. **系统设置** → 隐私与安全性 → **备忘录** → 勾选终端 / 脚本编辑器
2. **系统设置** → 隐私与安全性 → **提醒事项** → 勾选终端
3. **系统设置** → 隐私与安全性 → **日历** → 勾选终端

### 步骤 4：配置默认账户（可选）

复制配置模板并修改：

```bash
cp skills/apple-productivity/.local.example.md skills/apple-productivity/.local.md
```

编辑 `.local.md` 设置你的默认账户：

```yaml
---
default_account: iCloud        # 你的 Apple 账户名（如 iCloud、谷歌 等）
default_reminder_list: 提醒事项  # 默认任务列表
default_calendar: 日历          # 默认日历
default_event_duration: 60      # 默认事件时长（分钟）
---
```

## 接入不同 AI Agent

### Claude Code（推荐）

项目中的 `skills/` 目录会被 Claude Code 自动识别，无需额外配置。

```bash
# 在项目目录下直接使用
cd apple-cowork
claude

# 然后对 Claude 说：
# "帮我创建一个提醒事项：明天下午3点完成项目报告"
# "列出我今天的日历事件"
# "创建一篇笔记，记录今天的会议要点"
```

### Cursor / Windsurf / Cline

1. 将 `skills/` 和 `scripts/` 目录复制到你的项目中（或保持独立目录）
2. 在 AI 对话中引用 SKILL.md 让 Agent 了解可用命令
3. Agent 通过终端执行脚本

```bash
# 示例：在 Cursor 中，告诉 AI 读取技能文件
# "请阅读 skills/apple-productivity/SKILL.md，然后帮我创建一个提醒"
```

### 其他 CLI / 脚本直接调用

不需要 AI Agent，也可以直接在终端使用：

```bash
# Notes
./skills/apple-notes/scripts/list-notes.sh
./skills/apple-notes/scripts/create-note.sh --name "我的笔记" --body "内容"

# Reminders
./skills/apple-productivity/scripts/create-reminder.sh --name "买咖啡" --due "2026-03-01 09:00"
./skills/apple-productivity/scripts/list-reminders.sh --status pending

# Calendar
./skills/apple-productivity/scripts/create-event.sh --title "周会" --start "2026-03-01 14:00" --end "2026-03-01 15:00"
./skills/apple-productivity/scripts/list-events.sh --date "2026-03-01"

# 跨模块
./skills/apple-productivity/scripts/sync-view.sh --date "2026-03-01"
./skills/apple-productivity/scripts/reminder-to-event.sh --name "买咖啡" --duration 30
```

## 功能模块

### 📝 Apple Notes 模块

受 Notion / Obsidian 启发的结构化笔记工具：

| 功能 | 说明 |
|------|------|
| Frontmatter 属性 | YAML 格式页面元数据 |
| STAR 框架 | 结构化问题分析（Situation / Task / Action / Result） |
| 8 种 Callout | NOTE / WARNING / TIP / KEY / TODO / SUCCESS / ERROR / QUESTION |
| 原生复选框 | Apple Notes 风格任务列表 |
| Markdown → HTML | 自动转换为 Apple Notes 兼容格式 |

```bash
# 从 Markdown 创建笔记
echo "# 标题

> [!NOTE] 重要说明
> 这是一条说明
" | ./scripts/note-with-style.sh --name "我的笔记"

# 从文件创建
./scripts/note-with-style.sh --name "项目总结" --file "summary.md"

# 更新现有笔记
./scripts/note-with-style.sh --name "项目总结" --file "summary.md" --update
```

### ✅ Apple Productivity 模块（Reminders + Calendar）

| 功能 | 脚本 |
|------|------|
| 创建任务 | `create-reminder.sh --name "名称" --due "时间" --priority 2` |
| 列出任务 | `list-reminders.sh [--status pending\|completed]` |
| 完成任务 | `complete-reminder.sh --name "名称" --toggle` |
| 搜索任务 | `search-reminders.sh --query "关键词"` |
| 创建事件 | `create-event.sh --title "标题" --start "时间" --end "时间"` |
| 列出事件 | `list-events.sh --date "日期" [--range week\|month]` |
| 查找空闲 | `find-free-time.sh --date "日期" --duration 60` |
| 任务→事件 | `reminder-to-event.sh --name "名称" --duration 60` |
| 事件→任务 | `event-to-reminder.sh --title "标题" --create-prep-task` |
| 同步视图 | `sync-view.sh --date "日期"` |

## 项目结构

```
apple-cowork/
├── scripts/                         # 顶层快捷脚本（Notes）
│   ├── note-with-style.sh           # 主脚本（Markdown → HTML 笔记）
│   ├── md-to-notes-html.py          # Markdown → Apple Notes HTML 转换器
│   ├── create-note.sh               # 创建纯文本笔记
│   ├── update-note.sh               # 更新笔记
│   ├── list-notes.sh                # 列出笔记
│   ├── get-note.sh                  # 获取笔记内容
│   └── search-notes.sh              # 搜索笔记
├── skills/
│   ├── apple-notes/                 # Notes 模块
│   │   ├── SKILL.md                 # AI Agent 技能描述
│   │   ├── scripts/                 # 完整脚本集（12 个）
│   │   └── templates/               # 笔记模板
│   └── apple-productivity/          # Productivity 模块
│       ├── SKILL.md                 # AI Agent 技能描述
│       ├── scripts/                 # 完整脚本集（17 个）
│       ├── templates/               # 任务/事件模板
│       └── .local.example.md        # 配置模板
├── templates/                       # 通用笔记模板
│   ├── meeting-notes.md             # 会议记录模板
│   ├── project-summary.md           # 项目总结模板
│   └── bug-analysis.md              # Bug 分析模板
├── docs/                            # 文档和可视化
│   ├── architecture-note.html       # 架构图（Apple Notes 版）
│   ├── apple-cowork-guide.html      # 完整指南（Apple Notes 版）
│   └── apple-cowork-architecture.html # 架构图（网页版）
└── README.md
```

## 技术特点

- **零依赖** — 仅使用 macOS 原生工具（AppleScript + Python3）
- **本地优先** — 所有数据在本地 Apple 账户，无需云服务
- **结构化输出** — 生成 Apple Notes 兼容的 HTML 格式
- **跨平台 Agent** — 不绑定任何 AI 平台，通用 shell 脚本接口

## 规划中

- 🔗 Notes ↔ Reminders 双向链接
- 📝 会议记录自动创建任务
- 📚 对话内容自动归档到 Notes

## 许可证

MIT License
