# Calendar AppleScript 参考指南

## 基本操作

### 获取所有日历

```applescript
tell application "Calendar"
    get name of every calendar
end tell
```

### 获取日历账户

```applescript
tell application "Calendar"
    get name of every account
end tell
```

## 创建操作

### 创建新事件

```applescript
tell application "Calendar"
    set newEvent to make new event at end of events of calendar "日历名" with properties {summary:"事件名称"}
    get id of newEvent
end tell
```

### 创建带详细信息的事件

```applescript
tell application "Calendar"
    set targetCalendar to calendar "日历名"
    set eventStart to date "2026-02-28 14:00:00"
    set eventEnd to date "2026-02-28 15:00:00"

    set newEvent to make new event at end of events of targetCalendar with properties {
        summary:"会议名称",
        start date:eventStart,
        end date:eventEnd,
        location:"会议室",
        note:"会议备注"
    }

    get id of newEvent
end tell
```

### 创建全天事件

```applescript
tell application "Calendar"
    set targetCalendar to calendar "日历名"

    -- 全天事件的开始和结束时间设为同一天的 00:00
    set eventStart to date "2026-02-28 00:00:00"
    set eventEnd to date "2026-02-28 00:00:00"

    set newEvent to make new event at end of events of targetCalendar with properties {
        summary:"生日",
        start date:eventStart,
        end date:eventEnd,
        allday event:true
    }
end tell
```

### 创建重复事件

```applescript
tell application "Calendar"
    set targetCalendar to calendar "日历名"
    set eventStart to date "2026-02-28 10:00:00"
    set eventEnd to date "2026-02-28 11:00:00"

    set newEvent to make new event at end of events of targetCalendar with properties {
        summary:"周会",
        start date:eventStart,
        end date:eventEnd,
        recurrence:"FREQ=WEEKLY;BYDAY=FR"  -- 每周五重复
    }
end tell
```

### 创建带参与者的事件

```applescript
tell application "Calendar"
    set targetCalendar to calendar "日历名"
    set eventStart to date "2026-02-28 14:00:00"
    set eventEnd to date "2026-02-28 15:00:00"

    set newEvent to make new event at end of events of targetCalendar with properties {
        summary:"项目会议",
        start date:eventStart,
        end date:eventEnd,
        location:"办公室"
    }

    -- 添加参与者（需要 Exchange 或 CalDAV 账户）
    tell newEvent
        make new attendee at end of attendees with properties {email:"zhangsan@example.com"}
        make new attendee at end of attendees with properties {email:"lisi@example.com"}
    end tell
end tell
```

## 读取操作

### 获取单个事件的详细信息

```applescript
tell application "Calendar"
    set targetCalendar to calendar "日历名"
    set targetEvent to first event of targetCalendar whose summary = "事件名称"

    return {
        summary:summary of targetEvent,
        start date:start date of targetEvent,
        end date:end date of targetEvent,
        location:location of targetEvent,
        note:note of targetEvent,
        allday event:allday event of targetEvent
    }
end tell
```

### 获取今日所有事件

```applescript
tell application "Calendar"
    set todayStart to (current date) - (hours of (current date)) * 1 hours - (minutes of (current date)) * 1 minutes - (seconds of (current date)) * 1 seconds
    set todayEnd to todayStart + 24 * 60 * 60

    set todayEvents to every event of calendar "日历名" whose start date ≥ todayStart and start date < todayEnd

    repeat with e in todayEvents
        log "事件：" & summary of e
        log "时间：" & (start date of e)
    end repeat
end tell
```

### 获取指定日期范围内的事件

```applescript
tell application "Calendar"
    set startDate to date "2026-02-01 00:00:00"
    set endDate to date "2026-02-28 23:59:59"

    set filteredEvents to every event of calendar "日历名" whose start date ≥ startDate and start date ≤ endDate

    repeat with e in filteredEvents
        log summary of e & " - " & (start date of e)
    end repeat
end tell
```

### 获取本周事件

```applescript
tell application "Calendar"
    -- 计算本周一和下周一
    set today to current date
    set weekdayNum to weekday of today
    set mondayOffset to (weekdayNum - 2) * 24 * 60 * 60  -- 2 = Monday
    set thisMonday to today - mondayOffset
    set nextMonday to thisMonday + 7 * 24 * 60 * 60

    set weekEvents to every event of calendar "日历名" whose start date ≥ thisMonday and start date < nextMonday

    repeat with e in weekEvents
        log summary of e
    end repeat
end tell
```

### 获取事件的参与者

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "会议名称"

    repeat with attendee in attendees of targetEvent
        log "参与者：" & (name of attendee) & " <" & (email of attendee) & ">"
        log "  状态：" & (attendance status of attendee)
    end repeat
end tell
```

## 更新操作

### 更新事件标题

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "旧标题"
    set summary of targetEvent to "新标题"
end tell
```

### 更新事件时间

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "事件名称"
    set start date of targetEvent to date "2026-03-01 10:00:00"
    set end date of targetEvent to date "2026-03-01 11:00:00"
end tell
```

### 更新事件地点

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "事件名称"
    set location of targetEvent to "新会议室"
end tell
```

### 更新事件备注

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "事件名称"
    set note of targetEvent to "新备注内容"
end tell
```

### 移动事件到另一个日历

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "旧日历" whose summary = "事件名称"
    set newCalendar to calendar "新日历"
    move targetEvent to newCalendar
end tell
```

## 删除操作

### 删除事件

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "事件名称"
    delete targetEvent
end tell
```

### 删除重复事件的单个实例

```applescript
tell application "Calendar"
    -- 删除特定日期的重复事件实例
    set targetEvent to first event of calendar "日历名" whose summary = "周会" and start date = date "2026-02-28 10:00:00"
    delete targetEvent
end tell
```

## 搜索操作

### 按标题搜索事件

```applescript
tell application "Calendar"
    set searchResults to every event of calendar "日历名" whose summary contains "关键词"

    repeat with e in searchResults
        log summary of e & " - " & (start date of e)
    end repeat
end tell
```

### 按地点搜索事件

```applescript
tell application "Calendar"
    set searchResults to every event of calendar "日历名" whose location contains "会议室"

    repeat with e in searchResults
        log summary of e & " @ " & (location of e)
    end repeat
end tell
```

## 日历管理

### 创建新日历

```applescript
tell application "Calendar"
    make new calendar at end of calendars with properties {name:"新日历名"}
end tell
```

### 删除日历

```applescript
tell application "Calendar"
    delete calendar "日历名"
end tell
```

### 重命名日历

```applescript
tell application "Calendar"
    set name of calendar "旧名称" to "新名称"
end tell
```

### 订阅日历（CalDAV）

```applescript
tell application "Calendar"
    subscribe "webcal://example.com/calendar.ics"
end tell
```

## 高级操作

### 检查事件是否存在

```applescript
tell application "Calendar"
    try
        set targetEvent to first event of calendar "日历名" whose summary = "事件名称"
        log "事件存在"
    on error
        log "事件不存在"
    end try
end tell
```

### 检测时间冲突

```applescript
tell application "Calendar"
    set checkStart to date "2026-02-28 14:00:00"
    set checkEnd to date "2026-02-28 15:00:00"

    set conflictingEvents to every event of calendar "日历名" whose (
        (start date < checkEnd) and (end date > checkStart)
    )

    if (count of conflictingEvents) > 0 then
        log "发现时间冲突："
        repeat with e in conflictingEvents
            log "  " & summary of e & " (" & (start date of e) & " - " & (end date of e) & ")"
        end repeat
    else
        log "时间可用"
    end if
end tell
```

### 查找空闲时间段

```applescript
on findFreeSlots(targetCalendar, startDate, endDate, slotDuration)
    tell application "Calendar"
        set busyEvents to every event of calendar targetCalendar whose start date ≥ startDate and end date ≤ endDate

        -- 简化版：返回事件之间的空隙
        set freeSlots to {}
        set currentTime to startDate

        repeat with e in busyEvents
            if start date of e > currentTime then
                set slotStart to currentTime
                set slotEnd to start date of e
                set slotMinutes to (slotEnd - slotStart) / 60

                if slotMinutes ≥ slotDuration then
                    set end of freeSlots to {start:slotStart, end:slotEnd}
                end if
            end if
            set currentTime to end date of e
        end repeat

        return freeSlots
    end tell
end findFreeSlots

-- 使用示例
tell application "Calendar"
    set startDate to date "2026-02-28 09:00:00"
    set endDate to date "2026-02-28 18:00:00"
    set freeSlots to findFreeSlots("日历名", startDate, endDate, 60)

    repeat with slot in freeSlots
        log "空闲时间：" & (start of slot) & " - " & (end of slot)
    end repeat
end tell
```

### 建议会议时间

```applescript
on suggestMeetingTime(targetCalendar, searchDate, duration)
    tell application "Calendar"
        -- 获取当天所有事件
        set dayStart to (searchDate - (hours of searchDate) * 1 hours) - (minutes of searchDate) * 1 minutes
        set dayEnd to dayStart + 24 * 60 * 60

        set dayEvents to every event of calendar targetCalendar whose start date ≥ dayStart and start date < dayEnd

        -- 按时间排序事件
        set sortedEvents to {}
        repeat with e in dayEvents
            set end of sortedEvents to e
        end repeat
        set sortedEvents to sort sortedEvents by start date

        -- 查找可用的时间段
        set currentTime to dayStart + 9 * 60 * 60  -- 从早上 9 点开始

        repeat with e in sortedEvents
            set eventStart to start date of e

            if eventStart - currentTime ≥ duration * 60 then
                return {suggestedStart:currentTime, suggestedEnd:currentTime + duration * 60}
            end if

            set currentTime to end date of e
        end repeat

        -- 如果所有事件都检查完了还有时间，返回最后的时间段
        if dayEnd - currentTime ≥ duration * 60 then
            return {suggestedStart:currentTime, suggestedEnd:currentTime + duration * 60}
        end if

        return missing value  -- 没有找到合适的时间
    end tell
end suggestMeetingTime
```

### 获取事件的 URL

```applescript
tell application "Calendar"
    set targetEvent to first event of calendar "日历名" whose summary = "事件名称"
    -- Calendar AppleScript 不直接提供 URL，但可以通过 ID 构造
    -- 格式：ical://event/事件 ID
end tell
```

## 从 Shell 调用 AppleScript

### 单行调用

```bash
osascript -e 'tell application "Calendar" to get summary of every event'
```

### 多行调用（HEREDOC）

```bash
osascript <<EOF
tell application "Calendar"
    set today to current date
    set todayEvents to every event of calendar "日历" whose start date ≥ today
    repeat with e in todayEvents
        log summary of e
    end repeat
end tell
EOF
```

### 创建事件

```bash
EVENT_TITLE="项目会议"
START_TIME="2026-02-28 14:00:00"
END_TIME="2026-02-28 15:00:00"
LOCATION="办公室"

osascript <<EOF
tell application "Calendar"
    set targetCalendar to calendar "日历"
    set eventStart to date "$START_TIME"
    set eventEnd to date "$END_TIME"

    make new event at end of events of targetCalendar with properties {
        summary:"$EVENT_TITLE",
        start date:eventStart,
        end date:eventEnd,
        location:"$LOCATION"
    }
end tell
EOF
```

### 处理特殊字符

```bash
EVENT_TITLE="项目\"启动\"会议"
osascript <<EOF
tell application "Calendar"
    make new event with properties {summary:"$EVENT_TITLE"}
end tell
EOF
```

## 错误处理

```applescript
tell application "Calendar"
    try
        -- 操作代码
        set targetEvent to first event of calendar "日历名" whose summary = "不存在的事件"
    on error errMsg number errNum
        log "错误号：" & errNum
        log "错误信息：" & errMsg

        -- 常见错误号
        -- -1728: 事件不存在
        -- -1700: 参数错误
        -- -1712: 超时
    end try
end tell
```

## 常见问题

### Q: 如何获取事件的唯一标识符？

```applescript
tell application "Calendar"
    get id of first event of calendar "日历名"
end tell
```

### Q: 如何打开特定事件？

```applescript
tell application "Calendar"
    show first event of calendar "日历名" whose summary = "事件名称"
end tell
```

### Q: 如何获取事件的持续时间（分钟）？

```applescript
tell application "Calendar"
    set e to first event of calendar "日历名"
    set durationMinutes to (end date of e - start date of e) / 60
    log durationMinutes
end tell
```

### Q: 如何判断事件是全天事件？

```applescript
tell application "Calendar"
    set e to first event of calendar "日历名"
    if allday event of e then
        log "这是全天事件"
    else
        log "这是普通事件"
    end if
end tell
```

## 常见错误号

| 错误号 | 描述 |
|--------|------|
| -1728 | 事件/日历不存在 |
| -1700 | 参数错误 |
| -1712 | 超时 |
| -1713 | 用户取消 |
| -1714 | 访问被拒绝（需要权限） |

## 权限说明

macOS Catalina (10.15) 及更高版本需要授予应用访问 Calendar 的权限：

1. 系统偏好设置 → 隐私与安全性 → 日历
2. 确保终端应用或脚本编辑器已勾选

## 时区处理

```applescript
-- AppleScript 日期默认使用系统时区
-- 如需处理特定时区，可以使用 GMT 偏移

tell application "Calendar"
    set gmtTime to (current date) + (8 * 60 * 60)  -- GMT+8
    -- 但 Calendar 会自动处理时区转换
end tell
```
