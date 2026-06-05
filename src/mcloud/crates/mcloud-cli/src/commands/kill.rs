use anyhow::Result;
use mcloud_common::config::McloudConfig;
use mcloud_common::protocol::Request;
use mcloud_common::task_id::TaskId;

use crate::ssh::SshSession;

/// Kill a running task on a remote node.
pub fn execute(task_id: &str, node: Option<String>) -> Result<()> {
    let config = McloudConfig::load()?;
    let (node_name, node_config) = config.resolve_node(node.as_deref())?;
    let task_id = TaskId::parse(task_id)?;

    eprintln!("🔪 Killing task {} on {}...", task_id, node_name);

    let mut session = SshSession::new(node_config)?;
    let response = session.send_request(&Request::KillTask {
        task_id: task_id.clone(),
    })?;

    match response {
        mcloud_common::protocol::Response::TaskKilled { task_id } => {
            eprintln!("✅ Task {} killed", task_id);
            Ok(())
        }
        mcloud_common::protocol::Response::Error { message } => {
            anyhow::bail!("{message}");
        }
        other => {
            anyhow::bail!("unexpected response: {:?}", other);
        }
    }
}
