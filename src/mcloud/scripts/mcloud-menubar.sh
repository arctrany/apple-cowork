#!/bin/bash
# <bitbar.title>mcloud Menubar</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>mcloud</bitbar.author>
# <bitbar.desc>Display remote Apple Silicon node metrics in the system tray.</bitbar.desc>

# SwiftBar plugin to display remote node stats in the macOS menu bar.
# Find mcloud binary
if command -v mcloud >/dev/null 2>&1; then
    MCLOUD_BIN="mcloud"
elif [ -f "$HOME/.local/bin/mcloud" ]; then
    MCLOUD_BIN="$HOME/.local/bin/mcloud"
elif [ -f "/usr/local/bin/mcloud" ]; then
    MCLOUD_BIN="/usr/local/bin/mcloud"
elif [ -f "$HOME/.cargo/bin/mcloud" ]; then
    MCLOUD_BIN="$HOME/.cargo/bin/mcloud"
else
    echo "☁️ mcloud not found"
    echo "---"
    echo "Install mcloud and add to PATH"
    exit 0
fi

# Fetch metrics in JSON format (uses default node)
METRICS=$("$MCLOUD_BIN" info --json 2>/dev/null || echo "")

if [ -z "$METRICS" ]; then
    echo "☁️ offline"
    echo "---"
    echo "Cannot reach remote node"
    echo "Refresh | refresh=true"
    exit 0
fi

# Parse JSON using python3 (macOS standard, avoids jq dependency)
PARSE_SCRIPT='
import json, sys
try:
    d = json.loads(sys.stdin.read())
    cpu = d.get("cpu_usage", 0.0)
    gpu = d.get("gpu_usage", 0.0)
    power = d.get("power_watts")
    power_str = f"{power:.1f}W" if power is not None else "N/A"
    temp = d.get("temperature_c")
    temp_str = f"{temp:.0f}°C" if temp is not None else "N/A"
    mem_used = d.get("memory_used", 0)
    mem_total = d.get("memory_total", 1)
    mem_pct = (mem_used / mem_total) * 100
    disk_used = d.get("storage_used", 0)
    disk_total = d.get("storage_total", 1)
    disk_pct = (disk_used / disk_total) * 100
    tasks = d.get("active_tasks", 0)
    node = d.get("node", "default")
    hostname = d.get("hostname", "unknown")
    
    # Header line in menubar
    print(f"☁️ {node}: {cpu:.0f}% CPU | {power_str}")
    print("---")
    print(f"Node: {node} ({hostname}) | md=false")
    print(f"CPU Usage: {cpu:.1f}%")
    print(f"GPU Usage: {gpu:.1f}%")
    print(f"Power Draw: {power_str}")
    print(f"Temperature: {temp_str}")
    print(f"Active Tasks: {tasks}")
    print(f"Memory: {mem_pct:.1f}% ({mem_used // 1024 // 1024 // 1024}GB / {mem_total // 1024 // 1024 // 1024}GB)")
    print(f"Storage: {disk_pct:.1f}% ({disk_used // 1024 // 1024 // 1024}GB / {disk_total // 1024 // 1024 // 1024}GB)")
    print("---")
    print("Open Dashboard | href=http://127.0.0.1:8080")
    print("Refresh | refresh=true")
except Exception as e:
    print("☁️ error")
    print("---")
    print(f"Failed to parse JSON: {e}")
'

echo "$METRICS" | python3 -c "$PARSE_SCRIPT"
