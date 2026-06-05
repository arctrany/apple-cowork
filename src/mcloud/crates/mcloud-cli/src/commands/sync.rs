use anyhow::Result;
use mcloud_common::config::McloudConfig;
use std::process::Command;

use crate::config::resolve_project_name;
use crate::ssh::format_rsync_host;

/// Manually sync project files to a remote node.
pub fn execute(node: Option<String>, project: Option<String>) -> Result<()> {
    let config = McloudConfig::load()?;
    let (node_name, node_config) = config.resolve_node(node.as_deref())?;
    let project = resolve_project_name(project)?;

    eprintln!("📦 Syncing '{}' → {}...", project, node_name);

    let rsync_host = format_rsync_host(&node_config.host);
    let remote_path = format!(
        "{}@{}:~/.mcloud/workspaces/{}/",
        node_config.user, rsync_host, project
    );

    let mut cmd = Command::new("rsync");
    cmd.args(["-avz", "--delete", "--compress", "--progress"]);

    for exclude in &config.sync.excludes {
        cmd.arg(format!("--exclude={exclude}"));
    }

    if node_config.port != 22 {
        cmd.args(["-e", &format!("ssh -p {}", node_config.port)]);
    }

    cmd.arg("./");
    cmd.arg(&remote_path);

    let status = cmd.status()?;
    if status.success() {
        eprintln!("✅ Sync complete");
        Ok(())
    } else {
        anyhow::bail!("rsync failed with exit code: {:?}", status.code());
    }
}
