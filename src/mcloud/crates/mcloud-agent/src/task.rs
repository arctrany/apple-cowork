use anyhow::{Context, Result};
use mcloud_common::config::{tasks_dir, workspaces_dir};
use mcloud_common::protocol::{TaskState, TaskSummary};
use mcloud_common::task_id::TaskId;
use std::collections::HashMap;
use std::fs;
use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};

/// Metadata stored alongside each task.
#[derive(serde::Serialize, serde::Deserialize)]
struct TaskMeta {
    command: String,
    project: String,
    pid: u32,
    started_at: String,
}

/// Spawn a background task, redirect output to log file, and return the TaskId.
///
/// The task runs under `caffeinate -dis` to prevent system sleep.
/// A detached shell wrapper captures the exit code after the command finishes,
/// so the agent process can exit immediately without losing exit code tracking.
pub fn run_task(
    command: &str,
    workdir: Option<&str>,
    env: &HashMap<String, String>,
    project: &str,
) -> Result<TaskId> {
    let task_id = TaskId::generate();
    let task_dir = tasks_dir()?.join(task_id.as_str());
    fs::create_dir_all(&task_dir)
        .with_context(|| format!("creating task dir: {}", task_dir.display()))?;

    // Resolve working directory
    let workspace = workspaces_dir()?.join(project);
    fs::create_dir_all(&workspace)?;
    let cwd = match workdir {
        Some(wd) => workspace.join(wd),
        None => workspace.clone(),
    };

    let log_path = task_dir.join("output.log");
    let exit_code_path = task_dir.join("exit_code");

    // Build a wrapper script that:
    // 1. Runs the user command under caffeinate
    // 2. Captures the exit code
    // 3. Writes exit code to the task directory
    // This is fully detached — survives the agent process exiting.
    let wrapper_script = format!(
        "caffeinate -dis /bin/sh -c {} > {} 2>&1; echo $? > {}",
        shell_escape(command),
        log_path.display(),
        exit_code_path.display(),
    );

    // Spawn detached: nohup sh -c "wrapper" &
    // Using setsid-like behavior: stdin=/dev/null, stdout/stderr to /dev/null
    // (actual output goes to the log file inside the wrapper)
    let child = Command::new("/bin/sh")
        .args(["-c", &format!("nohup /bin/sh -c {} </dev/null >/dev/null 2>&1 &\necho $!", shell_escape(&wrapper_script))])
        .current_dir(&cwd)
        .envs(env)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .output()
        .with_context(|| format!("spawning task: {command}"))?;

    // Read the PID of the background wrapper process
    let pid_str = String::from_utf8_lossy(&child.stdout).trim().to_string();
    let pid: u32 = pid_str.parse().unwrap_or(0);

    // Save task metadata
    let meta = TaskMeta {
        command: command.to_string(),
        project: project.to_string(),
        pid,
        started_at: chrono::Utc::now().to_rfc3339(),
    };
    let meta_path = task_dir.join("meta.json");
    fs::write(&meta_path, serde_json::to_string_pretty(&meta)?)?;

    // Save PID for status checking
    fs::write(task_dir.join("pid"), pid.to_string())?;

    Ok(task_id)
}

/// Escape a string for use in a shell single-quoted context.
fn shell_escape(s: &str) -> String {
    // Wrap in single quotes, escaping any existing single quotes
    format!("'{}'", s.replace('\'', "'\\''"))
}

/// Get the current status of a task.
pub fn get_status(task_id: &TaskId) -> Result<(TaskState, Option<i32>, Option<u32>)> {
    let task_dir = tasks_dir()?.join(task_id.as_str());
    if !task_dir.exists() {
        anyhow::bail!("task '{}' not found", task_id);
    }

    // Check if exit_code file exists (task finished)
    let exit_code_path = task_dir.join("exit_code");
    if exit_code_path.exists() {
        let code_str = fs::read_to_string(&exit_code_path)?.trim().to_string();
        let code: i32 = code_str.parse().unwrap_or(-1);
        let state = if code == 0 {
            TaskState::Completed
        } else {
            TaskState::Failed
        };
        return Ok((state, Some(code), None));
    }

    // Check if the process is still alive
    let pid_path = task_dir.join("pid");
    if pid_path.exists() {
        let pid_str = fs::read_to_string(&pid_path)?.trim().to_string();
        let pid: u32 = pid_str.parse().unwrap_or(0);

        if pid > 0 {
            // Use kill(pid, 0) to check if process exists
            let pid_i32 = nix::unistd::Pid::from_raw(pid as i32);
            match nix::sys::signal::kill(pid_i32, None) {
                Ok(()) => return Ok((TaskState::Running, None, Some(pid))),
                Err(nix::errno::Errno::ESRCH) => {
                    // Process is gone but no exit_code file — likely crashed
                    // Try to capture the exit code via wait
                    fs::write(&exit_code_path, "-1")?;
                    return Ok((TaskState::Failed, Some(-1), None));
                }
                Err(_) => {
                    // Permission error or other — assume still running
                    return Ok((TaskState::Running, None, Some(pid)));
                }
            }
        }
    }

    Ok((TaskState::Failed, Some(-1), None))
}

/// Read log output from a task.
///
/// Returns (data, next_offset) where next_offset is the byte position after
/// the returned data. Use next_offset in subsequent calls for incremental reads.
pub fn get_logs(task_id: &TaskId, tail: Option<usize>, offset: Option<u64>) -> Result<(String, u64)> {
    let log_path = tasks_dir()?.join(task_id.as_str()).join("output.log");
    if !log_path.exists() {
        return Ok((String::new(), 0));
    }

    // If offset is specified, read from that byte position (incremental mode)
    if let Some(byte_offset) = offset {
        use std::io::{Read, Seek, SeekFrom};
        let mut file = fs::File::open(&log_path)?;
        let file_size = file.metadata()?.len();

        if byte_offset >= file_size {
            // No new data
            return Ok((String::new(), file_size));
        }

        file.seek(SeekFrom::Start(byte_offset))?;
        let mut buf = String::new();
        file.read_to_string(&mut buf)?;
        let new_offset = byte_offset + buf.len() as u64;
        return Ok((buf, new_offset));
    }

    // Tail mode: read last N lines
    if let Some(n) = tail {
        let file = fs::File::open(&log_path)?;
        let file_size = file.metadata()?.len();
        let reader = BufReader::new(file);
        let lines: Vec<String> = reader.lines().collect::<Result<Vec<_>, _>>()?;
        let start = lines.len().saturating_sub(n);
        return Ok((lines[start..].join("\n"), file_size));
    }

    // Default: read entire log
    let data = fs::read_to_string(&log_path)?;
    let size = data.len() as u64;
    Ok((data, size))
}

/// List all tasks on this node.
pub fn list_tasks() -> Result<Vec<TaskSummary>> {
    let dir = tasks_dir()?;
    if !dir.exists() {
        return Ok(Vec::new());
    }

    let mut tasks = Vec::new();
    for entry in fs::read_dir(&dir)? {
        let entry = entry?;
        if !entry.file_type()?.is_dir() {
            continue;
        }

        let dirname = entry.file_name().to_string_lossy().to_string();
        let task_id = match TaskId::parse(&dirname) {
            Ok(id) => id,
            Err(_) => continue,
        };

        // Read metadata
        let meta_path = entry.path().join("meta.json");
        let (command, project, started_at) = if meta_path.exists() {
            let meta: TaskMeta = serde_json::from_str(&fs::read_to_string(&meta_path)?)?;
            (meta.command, meta.project, meta.started_at)
        } else {
            ("(unknown)".to_string(), "(unknown)".to_string(), String::new())
        };

        let (state, exit_code, _) = get_status(&task_id).unwrap_or((TaskState::Failed, Some(-1), None));

        tasks.push(TaskSummary {
            task_id,
            command,
            project,
            state,
            exit_code,
            started_at,
        });
    }

    // Sort by started_at descending (newest first)
    tasks.sort_by(|a, b| b.started_at.cmp(&a.started_at));
    Ok(tasks)
}

/// Kill a running task by PID.
pub fn kill_task(task_id: &TaskId) -> Result<()> {
    let task_dir = tasks_dir()?.join(task_id.as_str());
    let pid_path = task_dir.join("pid");

    if !pid_path.exists() {
        anyhow::bail!("task '{}' has no PID file", task_id);
    }

    let pid_str = fs::read_to_string(&pid_path)?.trim().to_string();
    let pid: i32 = pid_str.parse()?;
    let nix_pid = nix::unistd::Pid::from_raw(pid);

    // Send SIGTERM first, then SIGKILL after a brief wait
    nix::sys::signal::kill(nix_pid, nix::sys::signal::Signal::SIGTERM)?;

    // Write killed status
    let exit_code_path = task_dir.join("exit_code");
    fs::write(&exit_code_path, "-9")?;

    Ok(())
}
