# Apple Cowork

> AI + Apple 生态互通方案 - 彻底解决 AI 与 Apple 生产力工具的整合

## 项目愿景

本项目旨在建立一套完整的工具链，让 AI 能够无缝与 Apple 生态中的生产力工具（Notes、Reminders、Calendar 等）进行交互，实现：

- 📝 **智能笔记管理** - 使用自然语言创建、更新、搜索 Apple Notes
- ✅ **任务自动化** - 将对话内容自动转化为 Reminders 任务
- 📅 **日程整合** - AI 协助管理 Calendar 日程安排
- 🔗 **知识互通** - 打破 AI 对话与 Apple 原生应用的数据孤岛

## 当前模块

### ✅ Apple Notes 模块

受 Notion/Obsidian 启发的结构化笔记工具，支持：

- **Frontmatter 属性** - 页面元数据管理
- **STAR 框架** - 结构化问题分析（Situation/Task/Action/Result）
- **Callout 块** - 8 种信息框（NOTE/WARNING/TIP/KEY/TODO/SUCCESS/ERROR/QUESTION）
- **复选框** - Apple Notes 原生风格的任务列表

#### 快速开始

```bash
# 创建笔记
echo "# 标题

> [!NOTE] 重要说明
" | ./scripts/note-with-style.sh --name "我的笔记"

# 从文件创建
./scripts/note-with-style.sh --name "项目总结" --file "summary.md"

# 更新笔记
./scripts/note-with-style.sh --name "项目总结" --file "summary.md" --update
```

详细文档：[skills/apple-notes/README.md](./skills/apple-notes/README.md)

### ✅ Apple Productivity 模块 (Reminders + Calendar)

完整的 Apple Reminders 和 Calendar 集成工具，支持：

- **任务管理** - 创建/读取/更新/删除/完成任务
- **日程管理** - 创建/读取/更新/删除日历事件
- **自然语言解析** - "明天下午 3 点开会"自动解析时间
- **空闲时间查询** - 查找可用的会议时间段
- **跨模块整合** - 任务↔日程双向转换，同步视图

#### 快速开始

```bash
cd skills/apple-productivity

# 创建任务
./scripts/create-reminder.sh --name "完成项目报告" --due "2026-02-28 15:00" --priority 2

# 创建事件
./scripts/create-event.sh --title "项目会议" --start "2026-02-28 14:00" --end "2026-02-28 15:00" --location "办公室"

# 同步视图（查看某天的任务和事件）
./scripts/sync-view.sh --date "2026-02-28"

# 任务转日程
./scripts/reminder-to-event.sh --name "完成项目报告" --duration 60

# 日程转任务（创建会前准备和会后跟进任务）
./scripts/event-to-reminder.sh --title "项目会议" --create-prep-task --create-followup-task
```

详细文档：[skills/apple-productivity/SKILL.md](./skills/apple-productivity/SKILL.md)

### 🚧 规划中模块

#### 跨模块整合增强
- Notes ↔ Reminders 双向链接
- 会议记录自动创建任务
- 对话内容自动归档

## 项目结构

```
apple-cowork/
├── scripts/           # 可执行脚本
│   ├── md-to-notes-html.py    # Markdown → Apple Notes HTML 转换器
│   ├── note-with-style.sh     # 主脚本（完整样式）
│   ├── note-from-markdown.sh  # 简化版 Markdown 转笔记
│   ├── create-note.sh         # 创建纯文本笔记
│   ├── update-note.sh         # 更新现有笔记
│   └── search-notes.sh        # 搜索笔记
├── src/               # 源代码（未来 Python 模块）
├── templates/         # 笔记模板
├── docs/              # 详细文档
├── README.md          # 项目说明
└── package.json       # 项目配置
```

## 技术特点

1. **零依赖** - 仅使用 macOS 原生工具（AppleScript、Python3）
2. **本地优先** - 所有数据存储在本地 Apple 账户
3. **结构化输出** - 生成 Apple Notes 兼容的 HTML 格式
4. **可扩展** - 模块化设计，易于添加新功能

## 安装

```bash
# 克隆项目
git clone https://github.com/arctrany/apple-cowork.git
cd apple-cowork

# 添加脚本到 PATH（可选）
export PATH="$PWD/scripts:$PATH"

# 安装 Python 依赖
pip3 install markdown pyyaml
```

## 配置

在 `~/.claude/plugins/cache/claude-plugins-official/apple-notes/.local.md` 配置默认值：

```markdown
default_folder: Notes
default_account: iCloud
```

## 使用示例

### 项目总结

```markdown
---
状态：已完成
负责人：张三
模块：后端
---

# 项目总结

::: star
Situation: 系统响应时间慢，用户体验差
Task: 将 API 响应时间从 500ms 降低到 100ms
Action: 重构数据库查询，引入 Redis 缓存
Result: 平均响应时间降至 80ms，转化率提升 15%
:::

## 核心进展

> [!KEY] 最重要的发现
> 通过引入缓存层，减少了 90% 的数据库查询

## 待办事项

- [x] 完成性能基准测试
- [ ] 编写技术文档
```

### 会议记录

```markdown
---
会议主题：周会
日期：2024-12-31
参会人：张三，李四
---

# 会议记录

## 讨论要点

> [!NOTE] 议题一
> 讨论内容...

## 行动项

- [ ] 张三 - 完成技术调研
- [ ] 李四 - 编写文档
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
