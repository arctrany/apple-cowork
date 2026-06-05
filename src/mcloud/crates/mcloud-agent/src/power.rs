use anyhow::Result;
use std::process::Command;

/// Gather node information: hostname, power draw, sleep settings, active tasks.
pub fn node_info() -> Result<(String, Option<f64>, Option<u32>, usize)> {
    let hostname = gethostname();
    let power_watts = read_cpu_power().ok();
    let sleep_setting = read_sleep_setting().ok();
    let active_tasks = count_active_tasks().unwrap_or(0);

    Ok((hostname, power_watts, sleep_setting, active_tasks))
}

/// Get the system hostname.
fn gethostname() -> String {
    nix::unistd::gethostname()
        .ok()
        .and_then(|h| h.into_string().ok())
        .unwrap_or_else(|| "(unknown)".to_string())
}

/// Parse `pmset -g` output to extract the system sleep setting.
///
/// Example output line: ` sleep		0 (sleep prevented by caffeinate)`
/// We extract the numeric value after "sleep".
fn read_sleep_setting() -> Result<u32> {
    let output = Command::new("pmset").arg("-g").output()?;
    let stdout = String::from_utf8_lossy(&output.stdout);

    for line in stdout.lines() {
        let trimmed = line.trim();
        // Match lines like: "sleep          0" or "sleep          10"
        // But NOT "displaysleep" or "disksleep"
        if trimmed.starts_with("sleep") && !trimmed.starts_with("sleepimage") {
            // Split on whitespace: ["sleep", "0", ...]
            let parts: Vec<&str> = trimmed.split_whitespace().collect();
            if parts.len() >= 2 {
                if let Ok(val) = parts[1].parse::<u32>() {
                    return Ok(val);
                }
            }
        }
    }

    anyhow::bail!("could not parse sleep setting from pmset output")
}

/// Try to read instantaneous CPU power from `powermetrics`.
///
/// Note: This requires root permissions. If unavailable, returns None.
/// We attempt to run it and gracefully fail if permissions are denied.
fn read_cpu_power() -> Result<f64> {
    // powermetrics needs root — try and fail gracefully
    let output = Command::new("sudo")
        .args([
            "-n", // non-interactive (fail if password needed)
            "powermetrics",
            "--samplers",
            "cpu_power",
            "-n",
            "1",
            "-i",
            "100",
        ])
        .output();

    match output {
        Ok(out) if out.status.success() => {
            let stdout = String::from_utf8_lossy(&out.stdout);
            // Look for "CPU Power: X.XX W" or "Combined Power (CPU + GPU + ANE): X.XX W"
            for line in stdout.lines() {
                if line.contains("CPU Power:") {
                    // Extract numeric value before " W"
                    if let Some(watts_str) = line.split(':').nth(1) {
                        let cleaned = watts_str
                            .trim()
                            .trim_end_matches(" mW")
                            .trim_end_matches(" W");
                        if let Ok(watts) = cleaned.parse::<f64>() {
                            // Convert mW to W if needed
                            if line.contains("mW") {
                                return Ok(watts / 1000.0);
                            }
                            return Ok(watts);
                        }
                    }
                }
            }
            anyhow::bail!("could not parse CPU power from powermetrics output")
        }
        _ => anyhow::bail!("powermetrics requires root access (sudo -n failed)"),
    }
}

/// Count active (running) tasks by checking PID files.
fn count_active_tasks() -> Result<usize> {
    let tasks_dir = mcloud_common::config::tasks_dir()?;
    if !tasks_dir.exists() {
        return Ok(0);
    }

    let mut count = 0;
    for entry in std::fs::read_dir(&tasks_dir)? {
        let entry = entry?;
        if !entry.file_type()?.is_dir() {
            continue;
        }

        let pid_path = entry.path().join("pid");
        let exit_code_path = entry.path().join("exit_code");

        // If there's a PID but no exit_code, the task might still be running
        if pid_path.exists() && !exit_code_path.exists() {
            let pid_str = std::fs::read_to_string(&pid_path)?;
            if let Ok(pid) = pid_str.trim().parse::<i32>() {
                let nix_pid = nix::unistd::Pid::from_raw(pid);
                if nix::sys::signal::kill(nix_pid, None).is_ok() {
                    count += 1;
                }
            }
        }
    }

    Ok(count)
}
