use anyhow::Result;
use mcloud_common::config::McloudConfig;
use mcloud_common::protocol::Request;

use crate::ssh::SshSession;

/// List all tasks on a remote node.
pub fn execute(node: Option<String>) -> Result<()> {
    let config = McloudConfig::load()?;
    let (node_name, node_config) = config.resolve_node(node.as_deref())?;

    eprintln!("📋 Tasks on {}:", node_name);

    let mut session = SshSession::new(node_config)?;
    let response = session.send_request(&Request::ListTasks)?;

    match response {
        mcloud_common::protocol::Response::TaskList { tasks } => {
            if tasks.is_empty() {
                println!("  (no tasks)");
                return Ok(());
            }

            // Print header
            println!(
                "  {:<22} {:<10} {:<6} {}",
                "TASK ID", "STATE", "EXIT", "COMMAND"
            );
            println!("  {}", "-".repeat(70));

            for task in &tasks {
                let state_str = format!("{:?}", task.state);
                let exit_str = task
                    .exit_code
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "-".to_string());
                let cmd_display = if task.command.len() > 40 {
                    format!("{}...", &task.command[..37])
                } else {
                    task.command.clone()
                };

                println!(
                    "  {:<22} {:<10} {:<6} {}",
                    task.task_id, state_str, exit_str, cmd_display
                );
            }

            println!("\n  Total: {} task(s)", tasks.len());
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
