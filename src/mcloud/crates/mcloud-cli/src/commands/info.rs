use anyhow::Result;
use mcloud_common::config::McloudConfig;
use mcloud_common::protocol::Request;

use crate::ssh::SshSession;

/// Display remote node information (power, tasks, hostname).
pub fn execute(node: Option<String>) -> Result<()> {
    let config = McloudConfig::load()?;
    let (node_name, node_config) = config.resolve_node(node.as_deref())?;

    eprintln!("ℹ️  Node info for {}:", node_name);

    let mut session = SshSession::new(node_config)?;
    let response = session.send_request(&Request::NodeInfo)?;

    match response {
        mcloud_common::protocol::Response::NodeInfo {
            hostname,
            power_watts,
            sleep_setting,
            active_tasks,
        } => {
            println!("  Hostname:      {}", hostname);
            println!("  Active Tasks:  {}", active_tasks);

            if let Some(watts) = power_watts {
                println!("  CPU Power:     {:.1} W", watts);
            } else {
                println!("  CPU Power:     (unavailable — needs sudo)");
            }

            if let Some(sleep) = sleep_setting {
                let sleep_str = if sleep == 0 {
                    "never (✅ correct for headless)".to_string()
                } else {
                    format!("{} minutes (⚠️  should be 0 for headless)", sleep)
                };
                println!("  Sleep Setting: {}", sleep_str);
            } else {
                println!("  Sleep Setting: (unavailable)");
            }

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
