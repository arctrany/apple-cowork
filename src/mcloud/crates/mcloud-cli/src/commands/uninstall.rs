use anyhow::Result;
use mcloud_common::config::{mcloud_home, McloudConfig};
use std::fs;
use std::process::Command;

/// Uninstall mcloud components.
///
/// Modes:
/// - Local:  remove CLI binary, config, task data, workspaces
/// - Remote: uninstall mcloud-agent from a remote node via SSH
pub fn execute(node: Option<String>, keep_data: bool) -> Result<()> {
    match node {
        Some(ref name) => uninstall_remote(name, keep_data),
        None => uninstall_local(keep_data),
    }
}

/// Uninstall mcloud from the local machine.
fn uninstall_local(keep_data: bool) -> Result<()> {
    println!("🗑️  Uninstalling mcloud (local)\n");

    // 1. Remove CLI binary
    let cli_path = which_mcloud();
    if let Some(path) = &cli_path {
        println!("  🔧 CLI binary: {}", path);
        match fs::remove_file(path) {
            Ok(()) => println!("     ✅ Removed"),
            Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
                println!("     ⚠️  Permission denied — run: sudo rm {}", path);
            }
            Err(e) => println!("     ⚠️  Could not remove: {}", e),
        }
    } else {
        println!("  ℹ️  CLI binary not found in PATH");
    }

    // 2. Unload and remove launchd agent (if installed locally)
    let plist_path = dirs::home_dir()
        .map(|h| h.join("Library/LaunchAgents/com.mcloud.agent.plist"));
    if let Some(ref plist) = plist_path {
        if plist.exists() {
            println!("  🔧 launchd plist: {}", plist.display());
            let _ = Command::new("launchctl")
                .args(["unload", &plist.display().to_string()])
                .output();
            match fs::remove_file(plist) {
                Ok(()) => println!("     ✅ Unloaded and removed"),
                Err(e) => println!("     ⚠️  Could not remove: {}", e),
            }
        }
    }

    // 3. Remove agent binary
    let agent_locations = [
        dirs::home_dir().map(|h| h.join(".local/bin/mcloud-agent")),
        Some(std::path::PathBuf::from("/usr/local/bin/mcloud-agent")),
    ];
    for loc in agent_locations.iter().flatten() {
        if loc.exists() {
            println!("  🔧 Agent binary: {}", loc.display());
            match fs::remove_file(loc) {
                Ok(()) => println!("     ✅ Removed"),
                Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
                    println!("     ⚠️  Permission denied — run: sudo rm {}", loc.display());
                }
                Err(e) => println!("     ⚠️  Could not remove: {}", e),
            }
        }
    }

    // 4. Remove data directory
    let mcloud_dir = mcloud_home()?;
    if mcloud_dir.exists() {
        if keep_data {
            println!("\n  📁 Data directory kept: {}", mcloud_dir.display());
            println!("     (use --purge to remove)");
        } else {
            println!("\n  🔧 Data directory: {}", mcloud_dir.display());
            // Show size before deleting
            let size = dir_size_human(&mcloud_dir);
            println!("     Size: {}", size);
            fs::remove_dir_all(&mcloud_dir)?;
            println!("     ✅ Removed");
        }
    }

    println!("\n✅ mcloud uninstalled from local machine.");
    Ok(())
}

/// Uninstall mcloud-agent from a remote node via SSH.
fn uninstall_remote(node_name: &str, keep_data: bool) -> Result<()> {
    let config = McloudConfig::load()?;
    let (_, node_config) = config.resolve_node(Some(node_name))?;

    println!("🗑️  Uninstalling mcloud-agent on '{}' ({})\n", node_name, node_config.host);

    let ssh_target = format!("{}@{}", node_config.user, node_config.host);
    let port = node_config.port.to_string();

    // Build remote uninstall script
    let purge_data = if keep_data {
        "echo '  📁 Data directory kept (~/.mcloud/)'"
    } else {
        "echo '  🔧 Removing data directory...' && rm -rf ~/.mcloud && echo '     ✅ Removed'"
    };

    let remote_script = format!(
        r#"
echo '🗑️  Uninstalling mcloud-agent...'
echo ''

# Unload launchd
if [ -f ~/Library/LaunchAgents/com.mcloud.agent.plist ]; then
    launchctl unload ~/Library/LaunchAgents/com.mcloud.agent.plist 2>/dev/null
    rm -f ~/Library/LaunchAgents/com.mcloud.agent.plist
    echo '  ✅ launchd plist unloaded and removed'
fi

# Remove agent binary from common locations
for p in ~/.local/bin/mcloud-agent /usr/local/bin/mcloud-agent; do
    if [ -f "$p" ]; then
        rm -f "$p" 2>/dev/null && echo "  ✅ Removed $p" || echo "  ⚠️  Cannot remove $p (try: sudo rm $p)"
    fi
done

# Kill any running mcloud-agent processes
pkill -f mcloud-agent 2>/dev/null && echo '  ✅ Killed running agent processes' || true

# Data directory
{purge_data}

echo ''
echo '✅ mcloud-agent uninstalled.'
"#
    );

    let output = Command::new("ssh")
        .args([
            "-o", "ConnectTimeout=10",
            "-p", &port,
            &ssh_target,
            &remote_script,
        ])
        .output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    print!("{stdout}");

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if !stderr.is_empty() {
            eprintln!("  ⚠️  SSH stderr: {}", stderr.trim());
        }
    }

    Ok(())
}

/// Find the mcloud CLI binary path.
fn which_mcloud() -> Option<String> {
    Command::new("which")
        .arg("mcloud")
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
}

/// Get human-readable directory size.
fn dir_size_human(path: &std::path::Path) -> String {
    let output = Command::new("du")
        .args(["-sh", &path.display().to_string()])
        .output();
    match output {
        Ok(o) if o.status.success() => {
            let s = String::from_utf8_lossy(&o.stdout);
            s.split_whitespace().next().unwrap_or("?").to_string()
        }
        _ => "unknown".to_string(),
    }
}
