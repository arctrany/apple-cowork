use anyhow::Result;
use mcloud_common::config::McloudConfig;
use mcloud_common::protocol::Request;
use mcloud_common::task_id::TaskId;

use crate::ssh::SshSession;

/// Retrieve and display logs from a remote task.
pub fn execute(
    task_id: &str,
    node: Option<String>,
    tail: Option<usize>,
    _follow: bool,
) -> Result<()> {
    let config = McloudConfig::load()?;
    let (_node_name, node_config) = config.resolve_node(node.as_deref())?;
    let task_id = TaskId::parse(task_id)?;

    let request = Request::GetLogs {
        task_id: task_id.clone(),
        tail,
        follow: false, // TODO: implement streaming follow mode
    };

    let mut session = SshSession::new(node_config)?;
    let response = session.send_request(&request)?;

    match response {
        mcloud_common::protocol::Response::LogChunk { data, .. } => {
            print!("{data}");
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
