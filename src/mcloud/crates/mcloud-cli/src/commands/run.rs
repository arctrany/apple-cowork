use anyhow::{Context, Result};
use mcloud_common::config::{McloudConfig, NodeConfig};
use mcloud_common::protocol::{Request, Response};
use std::process::Command;

use crate::config::resolve_project_name;
use crate::ssh::{format_rsync_host, SshSession};

/// Execute a command on a remote compute node.
///
/// Workflow:
/// 1. Load config, resolve target node
/// 2. rsync push: sync project files to remote workspace
/// 3. SSH to mcloud-agent with RunTask request
/// 4. Stream task output
pub fn execute(
    command: Vec<String>,
    node: Option<String>,
    no_sync: bool,
    project: Option<String>,
) -> Result<()> {
    let config = McloudConfig::load()?;
    let (node_name, node_config) = config.resolve_node(node.as_deref())?;
    let project = resolve_project_name(project)?;
    let full_command = command.join(" ");

    eprintln!("⚡ mcloud run → {} @ {}", full_command, node_name);

    // Step 1: Sync files
    if !no_sync {
        eprintln!("📦 Syncing project '{}' to {}...", project, node_name);
        sync_project(&config, node_config, &project)?;
        eprintln!("✅ Sync complete");
    }

    // Step 2: Send RunTask request
    eprintln!("🚀 Starting task on {}...", node_name);
    let request = Request::RunTask {
        command: full_command.clone(),
        workdir: None,
        env: std::collections::HashMap::new(),
        project: project.clone(),
    };

    let mut session = SshSession::new(node_config)?;
    let response = session.send_request(&request)?;

    match response {
        Response::TaskStarted { task_id } => {
            eprintln!("✅ Task started: {}", task_id);
            eprintln!();

            // Stream logs incrementally while polling for completion
            let mut offset: u64 = 0;

            loop {
                std::thread::sleep(std::time::Duration::from_millis(500));

                // Fetch new log output since last offset
                let log_request = Request::GetLogs {
                    task_id: task_id.clone(),
                    tail: None,
                    offset: Some(offset),
                    follow: true,
                };
                let mut log_session = SshSession::new(node_config)?;
                if let Response::LogChunk { data, next_offset, .. } =
                    log_session.send_request(&log_request)?
                {
                    if !data.is_empty() {
                        print!("{data}");
                        offset = next_offset;
                    }
                }

                // Check task status
                let mut check_session = SshSession::new(node_config)?;
                let status_resp = check_session.send_request(&Request::GetStatus {
                    task_id: task_id.clone(),
                })?;

                match status_resp {
                    Response::TaskStatus {
                        state,
                        exit_code,
                        ..
                    } => {
                        use mcloud_common::protocol::TaskState;
                        match state {
                            TaskState::Running => continue,
                            TaskState::Completed => {
                                // Drain any remaining output
                                let mut final_session = SshSession::new(node_config)?;
                                if let Response::LogChunk { data, .. } =
                                    final_session.send_request(&Request::GetLogs {
                                        task_id: task_id.clone(),
                                        tail: None,
                                        offset: Some(offset),
                                        follow: false,
                                    })?
                                {
                                    if !data.is_empty() {
                                        print!("{data}");
                                    }
                                }
                                eprintln!("\n✅ Task completed (exit code: 0)");
                                return Ok(());
                            }
                            TaskState::Failed | TaskState::Killed => {
                                // Drain remaining output
                                let mut final_session = SshSession::new(node_config)?;
                                if let Response::LogChunk { data, .. } =
                                    final_session.send_request(&Request::GetLogs {
                                        task_id: task_id.clone(),
                                        tail: None,
                                        offset: Some(offset),
                                        follow: false,
                                    })?
                                {
                                    if !data.is_empty() {
                                        print!("{data}");
                                    }
                                }
                                let code = exit_code.unwrap_or(-1);
                                eprintln!("\n❌ Task failed (exit code: {})", code);
                                std::process::exit(code);
                            }
                        }
                    }
                    Response::Error { message } => {
                        anyhow::bail!("error checking status: {message}");
                    }
                    _ => continue,
                }
            }
        }
        Response::Error { message } => {
            anyhow::bail!("failed to start task: {message}");
        }
        other => {
            anyhow::bail!("unexpected response: {:?}", other);
        }
    }
}

/// Sync project files to the remote node using rsync.
/// Supports both IPv4 and IPv6 addresses.
fn sync_project(config: &McloudConfig, node: &NodeConfig, project: &str) -> Result<()> {
    // Build rsync remote path (IPv6 addresses need brackets)
    let rsync_host = format_rsync_host(&node.host);
    let remote_path = format!(
        "{}@{}:~/.mcloud/workspaces/{}/",
        node.user, rsync_host, project
    );

    let mut cmd = Command::new("rsync");
    cmd.args([
        "-avz",
        "--delete",
        "--compress",
    ]);

    // Add excludes
    for exclude in &config.sync.excludes {
        cmd.arg(format!("--exclude={exclude}"));
    }

    // SSH options (pass port if non-default)
    let ssh_cmd = if node.port != 22 {
        format!("ssh -p {}", node.port)
    } else {
        "ssh".to_string()
    };
    cmd.args(["-e", &ssh_cmd]);

    // Source and destination
    cmd.arg("./");
    cmd.arg(&remote_path);

    let output = cmd.output().context("failed to run rsync")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("rsync failed:\n{stderr}");
    }

    Ok(())
}
