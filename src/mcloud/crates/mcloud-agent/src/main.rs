mod power;
mod task;
mod workspace;

use anyhow::Result;
use mcloud_common::protocol::{Request, Response};
use std::io::{self, BufRead, Write};

fn main() -> Result<()> {
    // Agent receives JSON requests on stdin and writes JSON responses to stdout.
    // This is invoked via `ssh host mcloud-agent` — SSH provides the transport.
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut stdout_lock = stdout.lock();

    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let response = match serde_json::from_str::<Request>(&line) {
            Ok(request) => handle_request(request),
            Err(e) => Response::Error {
                message: format!("invalid request: {e}"),
            },
        };

        let json = serde_json::to_string(&response)?;
        writeln!(stdout_lock, "{json}")?;
        stdout_lock.flush()?;
    }

    Ok(())
}

fn handle_request(request: Request) -> Response {
    match request {
        Request::RunTask {
            command,
            workdir,
            env,
            project,
        } => match task::run_task(&command, workdir.as_deref(), &env, &project) {
            Ok(task_id) => Response::TaskStarted { task_id },
            Err(e) => Response::Error {
                message: format!("failed to start task: {e}"),
            },
        },

        Request::GetStatus { task_id } => match task::get_status(&task_id) {
            Ok((state, exit_code, pid)) => Response::TaskStatus {
                task_id,
                state,
                exit_code,
                pid,
            },
            Err(e) => Response::Error {
                message: format!("failed to get status: {e}"),
            },
        },

        Request::GetLogs {
            task_id,
            tail,
            follow: _,
        } => match task::get_logs(&task_id, tail) {
            Ok(data) => Response::LogChunk { task_id, data },
            Err(e) => Response::Error {
                message: format!("failed to get logs: {e}"),
            },
        },

        Request::ListTasks => match task::list_tasks() {
            Ok(tasks) => Response::TaskList { tasks },
            Err(e) => Response::Error {
                message: format!("failed to list tasks: {e}"),
            },
        },

        Request::KillTask { task_id } => match task::kill_task(&task_id) {
            Ok(()) => Response::TaskKilled { task_id },
            Err(e) => Response::Error {
                message: format!("failed to kill task: {e}"),
            },
        },

        Request::NodeInfo => match power::node_info() {
            Ok((hostname, power_watts, sleep_setting, active_tasks)) => Response::NodeInfo {
                hostname,
                power_watts,
                sleep_setting,
                active_tasks,
            },
            Err(e) => Response::Error {
                message: format!("failed to get node info: {e}"),
            },
        },
    }
}
