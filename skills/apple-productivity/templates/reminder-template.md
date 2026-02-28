---
类型：提醒事项
创建日期：YYYY-MM-DD
优先级：中
截止时间：YYYY-MM-DD HH:MM
列表：提醒事项
状态：待完成
---

# 任务名称

## 描述

在此处填写任务的详细描述...

## 子任务

- [ ] 子任务 1
- [ ] 子任务 2
- [ ] 子任务 3

## 相关备注

在此处添加额外的备注信息...

## 关联事件

- 关联的日历事件：[事件名称](#)

---

## 使用指南

### 通过脚本创建

```bash
# 简单任务
./scripts/create-reminder.sh --name "任务名称" --due "2026-02-28 15:00" --priority 2

# 自然语言输入
./scripts/create-reminder.sh --parse "明天下午 3 点完成项目报告"

# 带备注
./scripts/create-reminder.sh --name "任务名称" --note "详细描述..." --due "2026-02-28 15:00"
```

### 常用命令

```bash
# 列出任务
./scripts/list-reminders.sh --status pending

# 获取详情
./scripts/get-reminder.sh --name "任务名称"

# 更新任务
./scripts/update-reminder.sh --name "任务名称" --due "新截止时间"

# 完成任务
./scripts/complete-reminder.sh --name "任务名称" --toggle

# 删除任务
./scripts/delete-reminder.sh --name "任务名称" --confirm
```

### 优先级说明

- 🔴 高（3）：紧急且重要
- 🟡 中（2）：重要但不紧急
- 🟢 低（1）：不紧急不重要
