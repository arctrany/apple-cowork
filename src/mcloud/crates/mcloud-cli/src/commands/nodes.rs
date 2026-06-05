use anyhow::Result;
use mcloud_common::config::McloudConfig;

/// List all configured nodes.
pub fn execute() -> Result<()> {
    let config = McloudConfig::load()?;

    if config.node.is_empty() {
        println!("No nodes configured.");
        println!("Run `mcloud init` to create a configuration file.");
        return Ok(());
    }

    println!("📡 Configured nodes:\n");
    println!(
        "  {:<15} {:<25} {:<10} {}",
        "NAME", "HOST", "USER", "DEFAULT"
    );
    println!("  {}", "-".repeat(60));

    for (name, node) in &config.node {
        let is_default = config
            .defaults
            .node
            .as_deref()
            .map(|d| d == name)
            .unwrap_or(false);
        let default_marker = if is_default { "⭐" } else { "" };

        println!(
            "  {:<15} {:<25} {:<10} {}",
            name, node.host, node.user, default_marker
        );
    }

    Ok(())
}
