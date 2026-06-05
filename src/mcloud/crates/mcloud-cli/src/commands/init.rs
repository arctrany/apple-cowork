use anyhow::Result;
use mcloud_common::config::McloudConfig;
use std::fs;

/// Generate a default configuration file at `~/.mcloud/config.toml`.
pub fn execute() -> Result<()> {
    let config_path = McloudConfig::default_path()?;

    if config_path.exists() {
        eprintln!(
            "⚠️  Config file already exists: {}",
            config_path.display()
        );
        eprintln!("   Remove it first if you want to regenerate.");
        return Ok(());
    }

    // Ensure directory exists
    if let Some(parent) = config_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let default_config = r#"# mcloud configuration
# Docs: https://github.com/arctrany/apple-cowork

# ── Compute Nodes ─────────────────────────────────────────────
# Define your remote Apple Silicon compute nodes here.
# Supports IPv4, IPv6 public addresses, and hostnames.

[node.mac-mini]
host = "2001:db8::1"         # IPv6 public address (or hostname / IPv4)
user = "your-username"       # SSH username on the remote node
# port = 22                  # SSH port (default: 22)

# Add more nodes:
# [node.mac-studio]
# host = "192.168.1.100"     # IPv4 also works
# user = "your-username"
#
# [node.ecs]
# host = "your-ecs.example.com"
# user = "root"

# ── File Sync ─────────────────────────────────────────────────
# Patterns to exclude from rsync sync.

[sync]
excludes = [
    "target/",
    "node_modules/",
    ".git/",
    "*.o",
    "*.pyc",
    "__pycache__/",
    ".DS_Store",
]

# ── Defaults ──────────────────────────────────────────────────

[defaults]
node = "mac-mini"            # Default node for `mcloud run`
"#;

    fs::write(&config_path, default_config)?;
    println!("✅ Created config file: {}", config_path.display());
    println!();
    println!("Next steps:");
    println!("  1. Edit {} and set your node hostname and user", config_path.display());
    println!("  2. Run `mcloud doctor` to verify connectivity");
    println!("  3. Run `mcloud run \"echo hello\"` to test");

    Ok(())
}
