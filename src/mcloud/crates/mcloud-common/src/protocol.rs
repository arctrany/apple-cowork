use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::task_id::TaskId;

// ─── CLI → Agent Requests ───────────────────────────────────────────────────

/// A request sent from the mcloud CLI to the remote mcloud-agent via SSH stdin.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum Request {
    /// Execute a command on the remote node.
    #[serde(rename = "run_task")]
    RunTask {
        /// The shell command to execute (e.g., "cargo build --release").
        command: String,
        /// Working directory relative to the workspace root.
        #[serde(default)]
        workdir: Option<String>,
        /// Additional environment variables.
        #[serde(default)]
        env: HashMap<String, String>,
        /// Project identifier for workspace isolation.
        project: String,
    },

    /// Query the status of a specific task.
    #[serde(rename = "get_status")]
    GetStatus { task_id: TaskId },

    /// Retrieve log output from a task.
    #[serde(rename = "get_logs")]
    GetLogs {
        task_id: TaskId,
        /// Number of lines from the end to retrieve. None = all lines.
        #[serde(default)]
        tail: Option<usize>,
        /// Byte offset to start reading from (for incremental follow).
        #[serde(default)]
        offset: Option<u64>,
        /// If true, this is a follow-mode request (client will poll).
        #[serde(default)]
        follow: bool,
    },

    /// List all tasks on this node.
    #[serde(rename = "list_tasks")]
    ListTasks,

    /// Kill a running task.
    #[serde(rename = "kill_task")]
    KillTask { task_id: TaskId },

    /// Query node health and power status.
    #[serde(rename = "node_info")]
    NodeInfo,
}

// ─── Agent → CLI Responses ──────────────────────────────────────────────────

/// A response sent from mcloud-agent back to the CLI via SSH stdout.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum Response {
    /// Task was successfully started.
    #[serde(rename = "task_started")]
    TaskStarted { task_id: TaskId },

    /// Current status of a task.
    #[serde(rename = "task_status")]
    TaskStatus {
        task_id: TaskId,
        state: TaskState,
        /// Exit code, only present when state is Completed or Failed.
        exit_code: Option<i32>,
        /// PID of the running process, only present when state is Running.
        pid: Option<u32>,
    },

    /// A chunk of log output.
    #[serde(rename = "log_chunk")]
    LogChunk {
        task_id: TaskId,
        data: String,
        /// Byte offset after this chunk (for next incremental fetch).
        #[serde(default)]
        next_offset: u64,
    },

    /// List of all tasks on this node.
    #[serde(rename = "task_list")]
    TaskList { tasks: Vec<TaskSummary> },

    /// Node health and power information.
    #[serde(rename = "node_info")]
    NodeInfo {
        hostname: String,
        /// Current power draw in watts (if available).
        power_watts: Option<f64>,
        /// pmset sleep setting (0 = never).
        sleep_setting: Option<u32>,
        /// Number of active tasks.
        active_tasks: usize,
    },

    /// Task was killed.
    #[serde(rename = "task_killed")]
    TaskKilled { task_id: TaskId },

    /// An error occurred processing the request.
    #[serde(rename = "error")]
    Error { message: String },
}

// ─── Shared Types ───────────────────────────────────────────────────────────

/// Lifecycle state of a task.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskState {
    /// Task is currently running.
    Running,
    /// Task completed successfully (exit code 0).
    Completed,
    /// Task failed (non-zero exit code).
    Failed,
    /// Task was killed by the user.
    Killed,
}

/// Summary of a task for listing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskSummary {
    pub task_id: TaskId,
    pub command: String,
    pub project: String,
    pub state: TaskState,
    pub exit_code: Option<i32>,
    pub started_at: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_request_serialization_roundtrip() {
        let req = Request::RunTask {
            command: "cargo build --release".to_string(),
            workdir: None,
            env: HashMap::new(),
            project: "my-project".to_string(),
        };
        let json = serde_json::to_string(&req).unwrap();
        let parsed: Request = serde_json::from_str(&json).unwrap();
        match parsed {
            Request::RunTask { command, .. } => {
                assert_eq!(command, "cargo build --release");
            }
            _ => panic!("unexpected variant"),
        }
    }

    #[test]
    fn test_response_serialization_roundtrip() {
        let resp = Response::TaskStatus {
            task_id: crate::task_id::TaskId::generate(),
            state: TaskState::Running,
            exit_code: None,
            pid: Some(12345),
        };
        let json = serde_json::to_string(&resp).unwrap();
        let parsed: Response = serde_json::from_str(&json).unwrap();
        match parsed {
            Response::TaskStatus { state, pid, .. } => {
                assert_eq!(state, TaskState::Running);
                assert_eq!(pid, Some(12345));
            }
            _ => panic!("unexpected variant"),
        }
    }
}
