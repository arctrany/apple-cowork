# Apple Notes Tech Writer 工具

## 概述

这是一个受 Notion/Obsidian 启发的 Apple Notes 笔记工具，支持结构化的技术文档编写。

**核心功能：**
- 📁 **文件夹层级管理** - 支持创建嵌套文件夹结构
- 🏷️ **标签系统** - Frontmatter 标签 + 智能索引笔记
- 📝 **结构化内容** - STAR 框架、Callout 块、属性网格
- ✅ **复选框** - Apple Notes 原生风格

---

## 快速开始

### 1. 创建文件夹结构

```bash
# 创建单层文件夹
./create-folder.sh "技术文档"

# 创建嵌套文件夹
./create-folder.sh "技术文档/Apple 生态"
./create-folder.sh "项目/apple-cowork/文档"
```

### 2. 创建带标签的笔记

```bash
# 使用参数定义标签和属性
./note-with-style.sh \
  --name "项目总结" \
  --file "summary.md" \
  --tags "Apple Notes，技术文档，自动化" \
  --status "已完成" \
  --owner "张三" \
  --module "Apple Notes 工具" \
  --folder "技术文档"
```

### 3. 更新索引笔记

```bash
# 扫描目录并生成索引
./update-index.sh --scan-dir "~/Documents/Notes" --output "笔记索引"
```

### 基本用法

```bash
# 从 Markdown 文件创建笔记
./note-with-style.sh --name "笔记名称" --file "input.md"

# 从命令行创建笔记
./note-with-style.sh --name "笔记名称" --body "# 标题

内容在这里"

# 从管道创建笔记
echo "# 标题" | ./note-with-style.sh --name "笔记名称"

# 更新现有笔记
./note-with-style.sh --name "笔记名称" --file "input.md" --update
```

---

## 命令行参数

### note-with-style.sh

| 参数 | 说明 | 示例 |
|------|------|------|
| `--name` | 笔记名称（必填） | `"项目总结"` |
| `--file` | Markdown 文件路径 | `input.md` |
| `--body` | Markdown 内容 | `"# 标题"` |
| `--folder` | 目标文件夹 | `"技术文档"` |
| `--tags` | 标签列表（逗号分隔） | `"标签 1, 标签 2"` |
| `--status` | 状态 | `已完成/进行中` |
| `--owner` | 负责人 | `张三` |
| `--module` | 模块 | `后端` |
| `--deadline` | 截止日期 | `2024-12-31` |
| `--update` | 更新模式 | （无值） |

### create-folder.sh

| 参数 | 说明 | 示例 |
|------|------|------|
| `路径` | 文件夹路径（必填） | `"技术文档/Apple"` |
| `--account` | 账户名 | `iCloud/On My Mac` |

### update-index.sh

| 参数 | 说明 | 示例 |
|------|------|------|
| `--scan-dir` | 扫描目录 | `~/Documents/Notes` |
| `--output` | 索引笔记名称 | `"笔记索引"` |
| `--folder` | 目标文件夹 | `"Notes"` |

## 支持的语法

### 1. 页面属性 (Frontmatter)

在笔记开头使用 YAML frontmatter 定义页面属性：

```markdown
---
状态：进行中
负责人：张三
模块：后端
截止：2024-12-31
---
```

会在笔记顶部显示为一个属性网格。

### 2. STAR 分析框架

使用 `::: star` 语法块创建 STAR 分析卡片：

```markdown
::: star
Situation: 系统响应时间慢，用户体验差
Task: 将 API 响应时间从 500ms 降低到 100ms
Action: 重构数据库查询，引入 Redis 缓存
Result: 平均响应时间降至 80ms，转化率提升 15%
:::
```

会显示为 2x2 的彩色卡片网格。

### 3. Callout 块（信息框）

支持 8 种类型的 callout 块：

```markdown
> [!NOTE] 注记内容
> 这是详细说明

> [!WARNING] 警告内容
> 需要注意的风险

> [!TIP] 提示内容
> 有用的建议和技巧

> [!KEY] 核心洞察
> 最重要的发现

> [!TODO] 待办事项
> 需要完成的任务

> [!SUCCESS] 成功经验
> 成功的案例和结果

> [!ERROR] 错误信息
> 错误和问题说明

> [!QUESTION] 问题
> 待解答的疑问
```

每个 callout 块都有独特的颜色和图标。

---

## 标签系统

### 定义标签

在 Frontmatter 中定义：

```yaml
---
标签：[Apple Notes, 技术文档，自动化]
状态：已完成
负责人：张三
---
```

### 命令行方式

```bash
./note-with-style.sh \
  --name "笔记" \
  --tags "标签 1, 标签 2, 标签 3" \
  --status "已完成"
```

### 索引笔记

运行 `./update-index.sh` 自动生成包含以下内容的索引笔记：

- 📊 **标签云** - 展示所有标签及笔记数量
- 📁 **按标签分组** - 每个标签下的笔记列表
- 🏷️ **未分类笔记** - 没有标签的笔记

### 4. 复选框

标准的 Markdown 复选框语法：

```markdown
- [x] 已完成的任务
- [ ] 未完成的任务
```

## 示例模板

### 项目总结模板

```markdown
---
状态：已完成
负责人：张三
模块：后端
日期：2024-12-31
---

# 项目总结

::: star
Situation: 描述问题背景
Task: 描述目标任务
Action: 描述采取的行动
Result: 描述结果产出
:::

## 核心进展

> [!KEY] 最重要的发现
> 这里写核心洞察

## 技术细节

> [!NOTE] 技术说明
> 详细的技术实现说明

## 风险与问题

> [!WARNING] 潜在风险
> 需要注意的问题

## 后续计划

- [ ] 性能优化
- [ ] 文档完善
- [x] 代码审查
```

### 会议记录模板

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

## 决策事项

> [!KEY] 重要决策
> 决策内容...

## 行动项

- [ ] 张三 - 完成技术调研
- [ ] 李四 - 编写文档
- [x] 王五 - 部署上线
```

### 问题分析模板

```markdown
---
问题类型：Bug
优先级：高
状态：调查中
---

# 问题分析

::: star
Situation: 用户报告登录失败
Task: 定位并修复登录问题
Action: 检查日志，发现数据库连接超时
Result: 增加连接池大小，问题已解决
:::

## 根因分析

> [!ERROR] 错误原因
> 数据库连接池配置过小

## 解决方案

> [!TIP] 解决方法
> 增加连接池大小到 100

## 预防措施

- [x] 增加监控告警
- [ ] 定期压力测试
```

## 配置文件

在 `~/.claude/plugins/cache/claude-plugins-official/apple-notes/.local.md` 中配置默认值：

```markdown
default_folder: Notes
default_account: iCloud
```

## 脚本说明

- `md-to-notes-html.py` - Markdown 转 Apple Notes HTML 转换器
- `note-with-style.sh` - 主脚本，支持完整样式功能
- `create-folder.sh` - 创建文件夹层级结构
- `update-index.sh` - 更新索引笔记
- `index-generator.py` - 索引生成器（Python）
- `note-from-markdown.sh` - 简化版 Markdown 转笔记脚本
- `create-note.sh` - 创建纯文本笔记
- `update-note.sh` - 更新现有笔记
- `search-notes.sh` - 搜索笔记

## 文档

- [笔记本管理指南](笔记本管理指南.md) - 完整的文件夹和标签系统文档

## 设计原则

1. **结构化** - 使用 STAR 框架等结构化工具组织思路
2. **可视化** - 使用颜色、图标等视觉元素增强可读性
3. **简洁** - 保持 HTML 简洁，兼容 Apple Notes 渲染
4. **实用** - 专注于技术文档和知识管理的实际需求
