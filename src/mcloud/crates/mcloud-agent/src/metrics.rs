use anyhow::Result;
use std::process::Command;
use std::thread;
use sysinfo::{Components, Disks, System};

pub struct SystemMetrics {
    pub hostname: String,
    pub cpu_usage: f64,
    pub gpu_usage: f64,
    pub temperature_c: Option<f64>,
    pub memory_used: u64,
    pub memory_total: u64,
    pub storage_used: u64,
    pub storage_total: u64,
    pub power_watts: Option<f64>,
    pub active_tasks: usize,
    pub battery_pct: Option<f64>,
    pub is_charging: Option<bool>,
}

pub fn get_system_metrics() -> Result<SystemMetrics> {
    // 1. Initialize system metrics collector
    let mut sys = System::new_all();
    
    // Refresh twice for CPU usage delta calculations
    sys.refresh_cpu();
    thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);
    sys.refresh_cpu();
    
    let hostname = nix::unistd::gethostname()
        .ok()
        .and_then(|h| h.into_string().ok())
        .unwrap_or_else(|| "(unknown)".to_string());
        
    let cpu_usage = sys.global_cpu_info().cpu_usage() as f64;
    let memory_used = sys.used_memory();
    let memory_total = sys.total_memory();
    
    // 2. Fetch Storage / Disk space
    let disks = Disks::new_with_refreshed_list();
    let mut total_space = 0;
    let mut available_space = 0;
    for disk in &disks {
        total_space += disk.total_space();
        available_space += disk.available_space();
    }
    let storage_total = total_space;
    let storage_used = total_space.saturating_sub(available_space);
    
    // 3. Fetch CPU/GPU temperatures
    let components = Components::new_with_refreshed_list();
    let mut cpu_temp = None;
    for component in &components {
        let label = component.label().to_lowercase();
        let temp = component.temperature() as f64;
        if label.contains("cpu") || label.contains("tdie") || label.contains("pmu tdie") {
            cpu_temp = Some(temp);
            break;
        }
        if cpu_temp.is_none() || Some(temp) > cpu_temp {
            cpu_temp = Some(temp);
        }
    }
    
    // 4. Fetch power draw and GPU residency via powermetrics
    let power_gpu = get_power_gpu_metrics();
    
    // 5. Active tasks
    let active_tasks = count_active_tasks().unwrap_or(0);
    
    // Sum CPU & GPU power for total power draw if both available
    let total_power = match (power_gpu.cpu_power_w, power_gpu.gpu_power_w) {
        (Some(cpu), Some(gpu)) => Some(cpu + gpu),
        (Some(cpu), None) => Some(cpu),
        (None, Some(gpu)) => Some(gpu),
        (None, None) => None,
    };

    // 6. Fetch battery state
    let (battery_pct, is_charging) = get_battery_metrics();
    
    Ok(SystemMetrics {
        hostname,
        cpu_usage,
        gpu_usage: power_gpu.gpu_active_pct.unwrap_or(0.0),
        temperature_c: cpu_temp,
        memory_used,
        memory_total,
        storage_used,
        storage_total,
        power_watts: total_power,
        active_tasks,
        battery_pct,
        is_charging,
    })
}

struct PowerGpuMetrics {
    cpu_power_w: Option<f64>,
    gpu_power_w: Option<f64>,
    gpu_active_pct: Option<f64>,
}

fn get_power_gpu_metrics() -> PowerGpuMetrics {
    let mut metrics = PowerGpuMetrics {
        cpu_power_w: None,
        gpu_power_w: None,
        gpu_active_pct: None,
    };

    let output = Command::new("sudo")
        .args([
            "-n",
            "powermetrics",
            "--samplers",
            "cpu_power,gpu_power",
            "-n",
            "1",
            "-i",
            "100",
        ])
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            let stdout = String::from_utf8_lossy(&out.stdout);
            for line in stdout.lines() {
                let line_lower = line.to_lowercase();
                if line_lower.contains("cpu power:") {
                    if let Some(val) = parse_power_line(line) {
                        metrics.cpu_power_w = Some(val);
                    }
                } else if line_lower.contains("gpu power:") {
                    if let Some(val) = parse_power_line(line) {
                        metrics.gpu_power_w = Some(val);
                    }
                } else if line_lower.contains("gpu active") {
                    if let Some(pct) = parse_percent_line(line) {
                        metrics.gpu_active_pct = Some(pct);
                    }
                }
            }
        }
    }

    metrics
}

fn parse_power_line(line: &str) -> Option<f64> {
    if let Some(val_str) = line.split(':').nth(1) {
        let trimmed = val_str.trim();
        let cleaned = trimmed
            .trim_end_matches(" mW")
            .trim_end_matches(" W")
            .trim();
        if let Ok(val) = cleaned.parse::<f64>() {
            if trimmed.contains("mW") {
                return Some(val / 1000.0);
            }
            return Some(val);
        }
    }
    None
}

fn parse_percent_line(line: &str) -> Option<f64> {
    if let Some(val_str) = line.split(':').nth(1) {
        let cleaned = val_str
            .trim()
            .trim_end_matches('%')
            .trim();
        if let Ok(val) = cleaned.parse::<f64>() {
            return Some(val);
        }
    }
    None
}

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

fn get_battery_metrics() -> (Option<f64>, Option<bool>) {
    let output = Command::new("pmset").args(["-g", "batt"]).output();
    if let Ok(out) = output {
        if out.status.success() {
            let stdout = String::from_utf8_lossy(&out.stdout);
            let mut pct = None;
            for line in stdout.lines() {
                if line.contains('%') {
                    if let Some(pct_idx) = line.find('%') {
                        let start_idx = line[..pct_idx]
                            .rfind(|c: char| !c.is_ascii_digit())
                            .map(|i| i + 1)
                            .unwrap_or(0);
                        if let Ok(parsed) = line[start_idx..pct_idx].parse::<f64>() {
                            pct = Some(parsed);
                        }
                    }
                }
            }
            let drawing_ac = stdout.contains("AC Power") || stdout.contains("AC attached");
            return (pct, Some(drawing_ac));
        }
    }
    (None, None)
}
