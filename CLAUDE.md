# Apple Cowork

AI + Apple 生态互通方案，通过 shell 脚本 + AppleScript 操作 Apple Notes、Reminders、Calendar。

## 项目结构

- `skills/apple-notes/` — Apple Notes 集成模块
- `skills/apple-productivity/` — Apple Reminders + Calendar 集成模块
- `docs/` — 设计文档和架构图

## 开发规范

- 所有脚本放在对应 skill 的 `scripts/` 目录下，不要在项目根目录创建脚本
- 脚本使用 `SCRIPT_DIR` 相对路径引用配置文件，不使用硬编码路径
- 配置文件使用 `.local.md`（YAML frontmatter 格式），模板文件为 `.local.example.md`
- `.local.md` 已在 `.gitignore` 中排除，不要提交用户配置
- 文档和 SKILL.md 统一使用中文
- 文件名使用 kebab-case（如 `create-note.sh`）
- 参考资料放在 `references/`，模板放在 `templates/`

## 脚本约定

- 所有脚本支持 `--help` 参数
- 使用统一的错误码体系（见 `skills/apple-productivity/SKILL.md`）
- 配置解析：通过 `grep` + `sed` 从 `.local.md` 的 YAML frontmatter 中提取值，需过滤行内注释
- 脚本头部使用 `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` 定位相对路径
