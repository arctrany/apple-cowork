---
类型：日历事件
创建日期：YYYY-MM-DD
开始时间：YYYY-MM-DD HH:MM
结束时间：YYYY-MM-DD HH:MM
日历：日历
地点：
参与者：
状态：已确认
---

# 事件名称

## 基本信息

- **时间**：YYYY-MM-DD HH:MM - HH:MM
- **地点**：地点名称
- **参与者**：张三、李四、王五

## 议程

1. 议题一（10 分钟）
2. 议题二（20 分钟）
3. 议题三（30 分钟）

## 会前准备

- [ ] 准备材料
- [ ] 发送会议邀请
- [ ] 预定会议室

## 会议记录

### 讨论要点

...

### 决策事项

...

## 会后跟进

- [ ] 发送会议纪要
- [ ] 跟进行动项 1
- [ ] 跟进行动项 2

## 关联任务

- [任务 1](#) - 会前准备
- [任务 2](#) - 会后跟进

---

## 使用指南

### 通过脚本创建

```bash
# 简单事件
./scripts/create-event.sh --title "事件名称" --start "2026-02-28 14:00" --end "2026-02-28 15:00"

# 自然语言输入
./scripts/create-event.sh --parse "明天下午 2 点到 3 点在办公室开项目会议"

# 带地点和备注
./scripts/create-event.sh --title "事件名称" --start "2026-02-28 14:00" --end "2026-02-28 15:00" --location "办公室" --note "会议备注"
```

### 常用命令

```bash
# 列出事件
./scripts/list-events.sh --date "2026-02-28"

# 获取详情
./scripts/get-event.sh --title "事件名称" --date "2026-02-28"

# 更新事件
./scripts/update-event.sh --title "事件名称" --new-start "2026-02-28 15:00"

# 删除事件
./scripts/delete-event.sh --title "事件名称" --date "2026-02-28" --confirm

# 查找空闲时间
./scripts/find-free-time.sh --date "2026-02-28" --duration 60

# 建议会议时间
./scripts/suggest-meeting-time.sh --duration 60 --range week
```

### 跨模块整合

```bash
# 从事件创建关联任务
./scripts/event-to-reminder.sh --title "事件名称" --create-prep-task --create-followup-task

# 同步视图
./scripts/sync-view.sh --date "2026-02-28"
```
