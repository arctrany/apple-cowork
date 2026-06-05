use anyhow::Result;
use mcloud_common::config::McloudConfig;
use std::process::Command;

/// Run diagnostic checks on connectivity and configuration.
pub fn execute(node: Option<String>) -> Result<()> {
    let config = McloudConfig::load()?;

    println!("🩺 mcloud doctor\n");

    // Check 1: Config file
    let config_path = McloudConfig::default_path()?;
    if config_path.exists() {
        println!("  ✅ Config file: {}", config_path.display());
    } else {
        println!("  ⚠️  Config file not found: {}", config_path.display());
        println!("     Run `mcloud init` to create one.");
    }

    // Check 2: rsync
    match Command::new("rsync").arg("--version").output() {
        Ok(output) if output.status.success() => {
            let version_line = String::from_utf8_lossy(&output.stdout)
                .lines()
                .next()
                .unwrap_or("unknown")
                .to_string();
            println!("  ✅ rsync: {}", version_line);
        }
        _ => {
            println!("  ❌ rsync not found — install with `brew install rsync`");
        }
    }

    // Check 3: IPv6 connectivity
    match Command::new("ifconfig")
        .output()
    {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let has_ipv6_global = stdout.lines().any(|line| {
                let trimmed = line.trim();
                trimmed.starts_with("inet6") && !trimmed.contains("::1") && !trimmed.contains("fe80")
            });
            if has_ipv6_global {
                println!("  ✅ IPv6: global address detected");
            } else {
                println!("  ⚠️  IPv6: no global unicast address found (only link-local/loopback)");
            }
        }
        _ => {
            println!("  ⚠️  IPv6: could not check (ifconfig unavailable)");
        }
    }

    // Check 4: SSH client
    match Command::new("ssh").arg("-V").output() {
        Ok(output) => {
            let version = String::from_utf8_lossy(&output.stderr); // ssh -V prints to stderr
            println!("  ✅ SSH: {}", version.trim());
        }
        Err(_) => {
            println!("  ❌ SSH client not found");
        }
    }

    // Check 5: Per-node connectivity
    let nodes_to_check: Vec<(&str, &mcloud_common::config::NodeConfig)> = match node.as_deref() {
        Some(name) => {
            let (n, c) = config.resolve_node(Some(name))?;
            vec![(n, c)]
        }
        None => config.node.iter().map(|(k, v)| (k.as_str(), v)).collect(),
    };

    if nodes_to_check.is_empty() {
        println!("\n  ⚠️  No nodes configured. Run `mcloud init` to set up.");
        return Ok(());
    }

    println!();
    for (name, node_config) in &nodes_to_check {
        let is_ipv6 = node_config.host.contains(':');
        let addr_type = if is_ipv6 { "IPv6" } else { "IPv4/hostname" };
        print!("  🔍 Node '{}' ({} {})... ", name, addr_type, node_config.host);

        // Ping test for IPv6 addresses
        if is_ipv6 {
            let ping_result = Command::new("ping6")
                .args(["-c", "1", "-W", "3", &node_config.host])
                .output();
            match ping_result {
                Ok(output) if output.status.success() => {
                    print!("ping ✅ ");
                }
                _ => {
                    println!("ping ❌ (IPv6 unreachable)");
                    continue;
                }
            }
        }

        // SSH connectivity test
        let ssh_result = Command::new("ssh")
            .args([
                "-o", "ConnectTimeout=5",
                "-o", "BatchMode=yes",
                "-p", &node_config.port.to_string(),
                &format!("{}@{}", node_config.user, node_config.host),
                "echo ok",
            ])
            .output();

        match ssh_result {
            Ok(output) if output.status.success() => {
                println!("SSH ✅");

                // Check if mcloud-agent is installed
                let agent_check = Command::new("ssh")
                    .args([
                        "-o", "ConnectTimeout=5",
                        "-p", &node_config.port.to_string(),
                        &format!("{}@{}", node_config.user, node_config.host),
                        "which mcloud-agent 2>/dev/null || echo NOT_FOUND",
                    ])
                    .output();

                if let Ok(out) = agent_check {
                    let stdout = String::from_utf8_lossy(&out.stdout);
                    if stdout.contains("NOT_FOUND") {
                        println!("     ⚠️  mcloud-agent not installed on {}", name);
                    } else {
                        println!("     ✅ mcloud-agent found: {}", stdout.trim());
                    }
                }

                // Check pmset on remote node
                let pmset_check = Command::new("ssh")
                    .args([
                        "-o", "ConnectTimeout=5",
                        "-p", &node_config.port.to_string(),
                        &format!("{}@{}", node_config.user, node_config.host),
                        "pmset -g | grep -E '^\\s*sleep\\s' | head -1",
                    ])
                    .output();

                if let Ok(out) = pmset_check {
                    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
                    if !stdout.is_empty() {
                        if stdout.contains(" 0") {
                            println!("     ✅ pmset sleep: {} (headless ready)", stdout.trim());
                        } else {
                            println!("     ⚠️  pmset sleep: {} (run setup-pmset.sh on node)", stdout.trim());
                        }
                    }
                }
            }
            Ok(output) => {
                let stderr = String::from_utf8_lossy(&output.stderr);
                println!("SSH ❌: {}", stderr.trim());
            }
            Err(e) => {
                println!("SSH ❌: {}", e);
            }
        }
    }

    Ok(())
}
