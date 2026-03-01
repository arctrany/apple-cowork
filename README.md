# Apple Cowork

> AI + Apple 生态互通方案 — 让任何 AI Code Agent 无缝操作 Apple Notes、Reminders、Calendar

## 工作原理

```
┌─────────────────┐     自然语言      ┌──────────────┐     bash 调用      ┌──────────────┐     AppleScript     ┌───────────────┐
│   AI Agent      │ ──────────────▶  │  SKILL.md    │ ──────────────▶  │  Shell 脚本   │ ──────────────▶   │  macOS 原生应用 │
│ (Claude Code /  │                  │  (技能描述)   │                  │  (scripts/)  │                   │  Notes /       │
│  Cursor / CLI)  │ ◀──────────────  │              │ ◀──────────────  │              │ ◀──────────────   │  Reminders /   │
└─────────────────┘   结构化结果      └──────────────┘   stdout 输出      └──────────────┘   osascript 返回    │  Calendar      │
                                                                                                          └───────────────┘
```

**核心原理：** 所有功能通过标准 shell 脚本 + AppleScript 实现，不依赖任何特定 AI 平台 API。只要你的 AI 工具能执行 bash 命令，就能使用全部功能。

## 安装

### 前置要求

- macOS 10.15 (Catalina) 或更高版本
- Python 3（macOS 自带）
- `pip3 install markdown pyyaml`（仅 Notes 的 Markdown 转换需要）

### 步骤 1：克隆仓库

```bash
git clone https://github.com/arctrany/apple-cowork.git
cd apple-cowork
```

### 步骤 2：授权脚本执行

```bash
chmod +x skills/apple-notes/scripts/*.sh
chmod +x skills/apple-productivity/scripts/*.sh
```

### 步骤 3：macOS 权限设置

首次运行脚本时，macOS 会弹出权限请求。你也可以提前在系统设置中授权：

1. **系统设置** → 隐私与安全性 → **备忘录** → 勾选终端
2. **系统设置** → 隐私与安全性 → **提醒事项** → 勾选终端
3. **系统设置** → 隐私与安全性 → **日历** → 勾选终端

### 步骤 4：配置默认账户（可选）

两个模块各有独立的配置文件，复制模板后编辑即可：

```bash
cp skills/apple-notes/.local.example.md skills/apple-notes/.local.md
cp skills/apple-productivity/.local.example.md skills/apple-productivity/.local.md
```

**Notes 模块** — `skills/apple-notes/.local.md`：

```yaml
---
default_account: iCloud        # 你的 Apple 账户名（如 iCloud、谷歌 等）
default_folder: Notes          # 默认笔记文件夹
---
```

**Productivity 模块** — `skills/apple-productivity/.local.md`：

```yaml
---
default_account: iCloud        # 你的 Apple 账户名
default_reminder_list: 提醒事项  # 默认任务列表
default_calendar: 日历          # 默认日历
default_event_duration: 60     # 默认事件时长（分钟）
---
```

## 使用方式

### Claude Code（推荐）

在 apple-cowork 目录下启动 Claude Code，`skills/` 目录会自动加载：

```bash
cd apple-cowork
claude

# 直接用自然语言：
# "帮我创建一个提醒事项：明天下午3点完成项目报告"
# "列出我今天的日历事件"
# "创建一篇笔记，记录今天的会议要点"
```

如果要在其他项目中使用，复制 `skills/` 目录到你的项目根目录：

```bash
cp -r /path/to/apple-cowork/skills /path/to/your-project/skills
```

### Cursor / Windsurf / Cline

1. 复制 `skills/` 目录到你的项目中
2. 在 AI 对话中引用 SKILL.md 让 Agent 了解可用命令

```
# 在 AI 对话中说：
"请阅读 skills/apple-productivity/SKILL.md，然后帮我创建一个提醒"
```

### 直接命令行调用

不需要 AI Agent，也可以在终端直接使用：

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

## 支持的 AI Code Agent

| Agent | 接入方式 | 状态 |
|-------|---------|------|
| **Claude Code** | `skills/` 目录自动加载 | ✅ 已验证 |
| **Cursor** | 复制 `skills/` 到项目，引用 SKILL.md | ✅ 兼容 |
| **Windsurf** | 复制 `skills/` 到项目，引用 SKILL.md | ✅ 兼容 |
| **Cline / Roo Code** | 复制 `skills/` 到项目，引用 SKILL.md | ✅ 兼容 |
| **其他 CLI 工具** | 任何能执行 bash 脚本的 AI 工具 | ✅ 兼容 |

## 功能一览

### Apple Notes 模块

| 功能 | 说明 |
|------|------|
| Frontmatter 属性 | YAML 格式页面元数据 |
| STAR 框架 | 结构化问题分析（Situation / Task / Action / Result） |
| 8 种 Callout | NOTE / WARNING / TIP / KEY / TODO / SUCCESS / ERROR / QUESTION |
| 原生复选框 | Apple Notes 风格任务列表 |
| Markdown → HTML | 自动转换为 Apple Notes 兼容格式 |

### Apple Productivity 模块（Reminders + Calendar）

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
├── .claude-plugin/
│   └── plugin.json          # Claude Code 插件清单
├── skills/
│   ├── apple-notes/         # Notes 模块
│   │   ├── SKILL.md         # 技能描述（AI Agent 自动加载）
│   │   ├── scripts/         # Shell 脚本
│   │   ├── templates/       # 笔记模板
│   │   ├── references/      # AppleScript 参考和指南
│   │   └── .local.example.md
│   └── apple-productivity/  # Reminders + Calendar 模块
│       ├── SKILL.md         # 技能描述
│       ├── scripts/         # Shell 脚本
│       ├── templates/       # 事件/任务模板
│       ├── references/      # AppleScript 参考
│       └── .local.example.md
└── docs/                    # 设计文档和架构图
```

## 技术特点

- **零依赖** — 仅使用 macOS 原生工具（AppleScript + Python3）
- **本地优先** — 所有数据在本地 Apple 账户，无需云服务
- **结构化输出** — 生成 Apple Notes 兼容的 HTML 格式
- **跨平台 Agent** — 不绑定任何 AI 平台，通用 shell 脚本接口

## 故障排除

### 权限被拒绝

**症状：** 脚本执行后报错 `Not authorized to send Apple events`

**解决方法：**
1. 打开 **系统设置** → **隐私与安全性**
2. 在「备忘录」「提醒事项」「日历」中勾选你的终端应用（Terminal / iTerm2 / Warp 等）
3. 如果使用 Claude Code，需要勾选 Claude Code 对应的终端
4. 修改后可能需要重启终端

### 账户名不匹配

**症状：** 脚本报错 `Account not found` 或返回空结果

**解决方法：**
1. 运行以下命令查看系统中的实际账户名：
   ```bash
   osascript -e 'tell application "Notes" to get name of every account'
   osascript -e 'tell application "Reminders" to get name of every account'
   ```
2. 将返回的账户名填入 `.local.md` 配置文件
3. 注意：中文系统的账户名可能是「iCloud」而非 "iCloud"

### Python 依赖缺失

**症状：** `note-from-markdown.sh` 报错 `ModuleNotFoundError: No module named 'markdown'`

**解决方法：**
```bash
pip3 install markdown pyyaml
```

### 脚本无执行权限

**症状：** `Permission denied` 错误

**解决方法：**
```bash
chmod +x skills/apple-notes/scripts/*.sh
chmod +x skills/apple-productivity/scripts/*.sh
```

## 许可证

MIT License
