#!/bin/bash
# deploy-to-node.sh — Deploy mcloud-agent to a remote Apple Silicon node
#
# Usage:
#   ./scripts/deploy-to-node.sh user@host [port]
#
# Example:
#   ./scripts/deploy-to-node.sh haowu@2001:db8::1
#   ./scripts/deploy-to-node.sh haowu@mac-mini 22

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 user@host [port]"
    echo ""
    echo "Examples:"
    echo "  $0 haowu@2001:db8::1      # IPv6"
    echo "  $0 haowu@192.168.1.100    # IPv4"
    echo "  $0 haowu@mac-mini 2222    # custom port"
    exit 1
fi

TARGET="$1"
PORT="${2:-22}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 mcloud-agent deployment${NC}"
echo "   Target: $TARGET (port $PORT)"
echo ""

# Step 1: Check if release binary exists
AGENT_BIN="$PROJECT_DIR/target/release/mcloud-agent"
if [ ! -f "$AGENT_BIN" ]; then
    echo -e "${YELLOW}⚙️  Building release binary...${NC}"
    (cd "$PROJECT_DIR" && cargo build --release)
fi

echo -e "  📦 Agent binary: $(du -h "$AGENT_BIN" | awk '{print $1}')"

# Step 2: SSH connectivity test
echo -ne "  🔍 SSH connectivity... "
if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$PORT" "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo "     Cannot reach $TARGET on port $PORT"
    echo "     Check: SSH keys, firewall, IPv6 reachability"
    exit 1
fi

# Step 3: Upload agent binary
echo -ne "  📤 Uploading mcloud-agent... "
ssh -p "$PORT" "$TARGET" "mkdir -p ~/.local/bin"
scp -P "$PORT" -q "$AGENT_BIN" "$TARGET:~/.local/bin/mcloud-agent"
echo -e "${GREEN}✅${NC}"

# Step 4: Verify it's in PATH and works
echo -ne "  🔧 Verifying installation... "
REMOTE_CHECK=$(ssh -p "$PORT" "$TARGET" 'export PATH="$HOME/.local/bin:$PATH" && which mcloud-agent && mcloud-agent <<< "{\"type\":\"node_info\"}" 2>/dev/null || echo FAIL')
if echo "$REMOTE_CHECK" | grep -q "FAIL"; then
    echo -e "${RED}❌${NC}"
    echo "     Agent installed but not working. Check ~/.local/bin is in PATH on remote."
    echo "     Add to remote ~/.zshrc:  export PATH=\"\$HOME/.local/bin:\$PATH\""
else
    echo -e "${GREEN}✅${NC}"
    # Parse hostname from response
    REMOTE_HOST=$(echo "$REMOTE_CHECK" | grep '"hostname"' | sed 's/.*"hostname":"\([^"]*\)".*/\1/')
    if [ -n "$REMOTE_HOST" ]; then
        echo "     Remote hostname: $REMOTE_HOST"
    fi
fi

# Step 5: Ensure ~/.local/bin is in remote PATH
echo -ne "  🔧 Checking remote PATH... "
PATH_OK=$(ssh -p "$PORT" "$TARGET" 'echo $PATH' | grep -c '.local/bin' || true)
if [ "$PATH_OK" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  ~/.local/bin not in PATH${NC}"
    echo "     Adding to remote ~/.zshrc..."
    ssh -p "$PORT" "$TARGET" 'grep -q ".local/bin" ~/.zshrc 2>/dev/null || echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc'
    echo -e "     ${GREEN}✅ Added${NC}"
else
    echo -e "${GREEN}✅${NC}"
fi

# Step 6: Create ~/.mcloud directory
ssh -p "$PORT" "$TARGET" "mkdir -p ~/.mcloud/tasks ~/.mcloud/workspaces"

# Step 7: Optional — configure pmset for headless mode
echo ""
echo -ne "  ⚡ Remote pmset sleep setting: "
SLEEP_VAL=$(ssh -p "$PORT" "$TARGET" "pmset -g | grep '^ sleep' | awk '{print \$2}'" 2>/dev/null || echo "?")
echo "$SLEEP_VAL"
if [ "$SLEEP_VAL" != "0" ] && [ "$SLEEP_VAL" != "?" ]; then
    echo -e "     ${YELLOW}⚠️  Sleep is enabled. For headless use, run on the remote node:${NC}"
    echo "        sudo pmset -a sleep 0 displaysleep 0 disksleep 0"
fi

# Done
echo ""
echo -e "${YELLOW}🔒 Would you like to configure passwordless sudo for powermetrics on the remote node?${NC}"
echo "   This enables CPU/GPU power tracking in the dashboard."
echo "   It requires running one sudo command on the remote node to write to /etc/sudoers.d/mcloud-powermetrics."
read -p "   Configure now? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   Running remote configuration..."
    ssh -t -p "$PORT" "$TARGET" '
        CURRENT_USER=$(whoami)
        RULE_LINE="$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/powermetrics"
        echo "Creating /etc/sudoers.d/mcloud-powermetrics..."
        sudo mkdir -p /etc/sudoers.d
        echo "$RULE_LINE" | sudo tee /etc/sudoers.d/mcloud-powermetrics >/dev/null
        sudo chmod 440 /etc/sudoers.d/mcloud-powermetrics
        sudo chown root:wheel /etc/sudoers.d/mcloud-powermetrics
        echo "✅ Passwordless powermetrics configured!"
    '
else
    echo "   Skipped. You can configure this manually later if you want power stats."
fi

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps on your local machine:"
echo "  1. Run: mcloud init"
echo "  2. Edit ~/.mcloud/config.toml — set host and user"
echo "  3. Run: mcloud doctor"
echo "  4. Run: mcloud run 'echo hello from remote'"
