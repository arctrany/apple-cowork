#!/bin/bash
# mcloud: Install mcloud-agent as a launchd user agent.
#
# This script:
# 1. Builds mcloud-agent from source (requires Rust toolchain)
# 2. Copies the binary to /usr/local/bin/
# 3. Installs the launchd plist to ~/Library/LaunchAgents/
# 4. Loads the agent
#
# Usage: ./install-agent.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_SRC="$PROJECT_DIR/resources/com.mcloud.agent.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.mcloud.agent.plist"
BINARY_DST="/usr/local/bin/mcloud-agent"

echo "🔨 Building mcloud-agent..."
cd "$PROJECT_DIR"
cargo build --release --bin mcloud-agent

BINARY_SRC="$PROJECT_DIR/target/release/mcloud-agent"

if [ ! -f "$BINARY_SRC" ]; then
    echo "❌ Build failed: $BINARY_SRC not found"
    exit 1
fi

echo "📦 Installing binary to $BINARY_DST..."
sudo cp "$BINARY_SRC" "$BINARY_DST"
sudo chmod 755 "$BINARY_DST"

echo "📋 Installing launchd plist..."
# Unload existing if present
launchctl unload "$PLIST_DST" 2>/dev/null || true

# Create LaunchAgents dir if needed
mkdir -p "$HOME/Library/LaunchAgents"

# Copy plist, substituting username
sed "s|__USER__|$(whoami)|g" "$PLIST_SRC" > "$PLIST_DST"

# Load the agent
launchctl load "$PLIST_DST"

echo ""
echo "✅ mcloud-agent installed and running!"
echo ""
echo "  Binary:  $BINARY_DST"
echo "  Plist:   $PLIST_DST"
echo "  Logs:    ~/.mcloud/agent.log"
echo ""
echo "  Check status: launchctl list | grep mcloud"
echo "  View logs:    tail -f ~/.mcloud/agent.log"
