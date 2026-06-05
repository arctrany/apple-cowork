#!/bin/bash
# mcloud: Configure macOS power settings for headless server mode.
#
# This script configures pmset to keep the system awake (CPU + network online)
# while turning off the display to minimize power consumption.
#
# On M-series chips, this configuration results in ~3.1-3.8W idle power draw,
# which is close to deep sleep but maintains full network connectivity.
#
# Usage: sudo ./setup-pmset.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run with sudo."
    echo "   Usage: sudo $0"
    exit 1
fi

echo "⚡ mcloud power configuration"
echo ""

# Turn off display after 10 minutes (saves GPU/display power)
echo "  Setting displaysleep = 10 minutes..."
pmset -a displaysleep 10

# Never sleep the system (keeps CPU + network alive)
echo "  Setting sleep = 0 (never)..."
pmset -a sleep 0

# Prevent sleep even when lid is closed (for MacBook nodes)
echo "  Setting disablesleep = 1 (lid-close safe)..."
pmset -a disablesleep 1

# Enable Wake on Network Access (for LAN magic packets)
echo "  Setting womp = 1 (Wake on LAN)..."
pmset -a womp 1

# Prevent idle sleep
echo "  Setting autopoweroff = 0..."
pmset -a autopoweroff 0

# Disable standby (deep idle hibernation)
echo "  Setting standby = 0..."
pmset -a standby 0

echo ""
echo "✅ Power configuration complete. Current settings:"
echo ""
pmset -g
echo ""
echo "💡 Tip: Verify idle power with: sudo powermetrics --samplers cpu_power -n 1"
