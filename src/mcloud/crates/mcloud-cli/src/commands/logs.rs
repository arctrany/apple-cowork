use anyhow::Result;
use mcloud_common::config::McloudConfig;
use mcloud_common::protocol::{Request, Response, TaskState};
use mcloud_common::task_id::TaskId;

use crate::ssh::SshSession;

/// Retrieve and display logs from a remote task.
///
/// With `--follow`, polls the agent every second for new log output,
/// printing incrementally until the task finishes.
pub fn execute(
    task_id: &str,
    node: Option<String>,
    tail: Option<usize>,
    follow: bool,
) -> Result<()> {
    let config = McloudConfig::load()?;
    let (_node_name, node_config) = config.resolve_node(node.as_deref())?;
    let task_id = TaskId::parse(task_id)?;

    if !follow {
        // One-shot: fetch all logs and print
        let request = Request::GetLogs {
            task_id: task_id.clone(),
            tail,
            offset: None,
            follow: false,
        };

        let mut session = SshSession::new(node_config)?;
        let response = session.send_request(&request)?;

        match response {
            Response::LogChunk { data, .. } => {
                print!("{data}");
                Ok(())
            }
            Response::Error { message } => anyhow::bail!("{message}"),
            other => anyhow::bail!("unexpected response: {:?}", other),
        }
    } else {
        // Follow mode: poll incrementally until task completes
        let mut offset: u64 = 0;
        let mut connection_lost = false;

        // If tail is specified, first fetch the tail, then switch to follow
        if tail.is_some() {
            let request = Request::GetLogs {
                task_id: task_id.clone(),
                tail,
                offset: None,
                follow: false,
            };
            let mut session = SshSession::new(node_config)?;
            if let Response::LogChunk { data, next_offset, .. } = session.send_request(&request)? {
                print!("{data}");
                offset = next_offset;
            }
        }

        loop {
            std::thread::sleep(std::time::Duration::from_millis(500));

            // Fetch incremental logs
            let log_request = Request::GetLogs {
                task_id: task_id.clone(),
                tail: None,
                offset: Some(offset),
                follow: true,
            };
            let mut log_session = SshSession::new(node_config)?;
            let log_resp = match log_session.send_request(&log_request) {
                Ok(resp) => {
                    if connection_lost {
                        eprintln!("\n✨ Connection restored.");
                        connection_lost = false;
                    }
                    resp
                }
                Err(e) => {
                    if !connection_lost {
                        eprintln!("\n⚠️  Connection to agent lost. Retrying... (Reason: {})", e);
                        connection_lost = true;
                    }
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    continue;
                }
            };

            match log_resp {
                Response::LogChunk { data, next_offset, .. } => {
                    if !data.is_empty() {
                        print!("{data}");
                        offset = next_offset;
                    }
                }
                Response::Error { message } => {
                    eprintln!("⚠️  log error: {message}");
                }
                _ => {}
            }

            // Check if task is still running
            let mut status_session = SshSession::new(node_config)?;
            let status_resp = match status_session.send_request(&Request::GetStatus {
                task_id: task_id.clone(),
            }) {
                Ok(resp) => resp,
                Err(e) => {
                    if !connection_lost {
                        eprintln!("\n⚠️  Connection to agent lost. Retrying... (Reason: {})", e);
                        connection_lost = true;
                    }
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    continue;
                }
            };

            if let Response::TaskStatus { state, exit_code, .. } = status_resp {
                match state {
                    TaskState::Running => continue,
                    TaskState::Completed => {
                        // Drain any remaining output
                        let _ = drain_remaining(node_config, &task_id, offset);
                        eprintln!("\n✅ Task completed (exit code: 0)");
                        return Ok(());
                    }
                    TaskState::Failed | TaskState::Killed => {
                        let _ = drain_remaining(node_config, &task_id, offset);
                        let code = exit_code.unwrap_or(-1);
                        eprintln!("\n❌ Task {} (exit code: {})",
                            if state == TaskState::Killed { "killed" } else { "failed" },
                            code);
                        return Ok(());
                    }
                }
            }
        }
    }
}

/// Fetch any remaining log data after a task finishes.
fn drain_remaining(
    node_config: &mcloud_common::config::NodeConfig,
    task_id: &TaskId,
    offset: u64,
) -> Result<()> {
    let request = Request::GetLogs {
        task_id: task_id.clone(),
        tail: None,
        offset: Some(offset),
        follow: false,
    };
    let mut session = SshSession::new(node_config)?;
    match session.send_request(&request) {
        Ok(Response::LogChunk { data, .. }) => {
            if !data.is_empty() {
                print!("{data}");
            }
        }
        Err(e) => {
            eprintln!("⚠️  Failed to drain final logs: {}", e);
        }
        _ => {}
    }
    Ok(())
}
