use anyhow::{Context, Result};
use mcloud_common::config::NodeConfig;
use mcloud_common::protocol::{Request, Response};
use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};

/// An SSH session to a remote mcloud-agent.
///
/// Communication protocol:
/// - Client sends one JSON-encoded `Request` line to stdin
/// - Agent reads it, processes, and writes one JSON-encoded `Response` line to stdout
///
/// Supports both IPv4 and IPv6 addresses (including bare IPv6 public addresses).
pub struct SshSession {
    host: String,
    user: String,
    port: u16,
}

/// Format a host for use in rsync remote paths.
/// IPv6 addresses must be wrapped in brackets: `user@[::1]:path`
/// IPv4/hostnames pass through unchanged: `user@host:path`
pub fn format_rsync_host(host: &str) -> String {
    if host.contains(':') {
        // IPv6 address — wrap in brackets for rsync
        format!("[{}]", host)
    } else {
        host.to_string()
    }
}

impl SshSession {
    pub fn new(config: &NodeConfig) -> Result<Self> {
        Ok(Self {
            host: config.host.clone(),
            user: config.user.clone(),
            port: config.port,
        })
    }

    /// Send a request to the remote mcloud-agent and return the response.
    pub fn send_request(&mut self, request: &Request) -> Result<Response> {
        let request_json = serde_json::to_string(request)?;

        // Build SSH command: ssh user@host mcloud-agent
        let mut cmd = Command::new("ssh");
        cmd.args([
            "-o", "ConnectTimeout=10",
            "-o", "BatchMode=yes",
            "-p", &self.port.to_string(),
            &format!("{}@{}", self.user, self.host),
            "mcloud-agent",
        ]);

        cmd.stdin(Stdio::piped());
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        let mut child = cmd.spawn().with_context(|| {
            format!("failed to SSH to {}@{}:{}", self.user, self.host, self.port)
        })?;

        // Write request to stdin
        if let Some(mut stdin) = child.stdin.take() {
            writeln!(stdin, "{}", request_json)?;
            // Drop stdin to signal EOF, which tells the agent to process
            drop(stdin);
        }

        // Read response from stdout
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| anyhow::anyhow!("failed to capture SSH stdout"))?;
        let mut reader = BufReader::new(stdout);
        let mut response_line = String::new();
        reader.read_line(&mut response_line)?;

        // Wait for SSH process to exit
        let status = child.wait()?;
        if !status.success() && response_line.is_empty() {
            let stderr = child.stderr.take().map(|s| {
                let mut buf = String::new();
                BufReader::new(s).read_line(&mut buf).ok();
                buf
            });
            anyhow::bail!(
                "SSH to {}@{} failed (exit {}): {}",
                self.user,
                self.host,
                status.code().unwrap_or(-1),
                stderr.unwrap_or_default().trim()
            );
        }

        let response: Response = serde_json::from_str(response_line.trim())
            .with_context(|| format!("invalid response from agent: {}", response_line.trim()))?;

        Ok(response)
    }
}
