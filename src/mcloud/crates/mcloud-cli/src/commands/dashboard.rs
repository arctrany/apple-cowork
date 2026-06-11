use anyhow::Result;
use mcloud_common::config::{McloudConfig, NodeConfig};
use mcloud_common::protocol::Request;
use serde_json::json;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread;

use crate::ssh::SshSession;

/// Start a local Web Dashboard to monitor remote nodes.
pub fn execute(port: u16) -> Result<()> {
    let listener = TcpListener::bind(format!("127.0.0.1:{}", port))?;
    println!("🚀 mcloud Dashboard running at http://127.0.0.1:{}", port);
    println!("   Press Ctrl+C to stop the dashboard server.");

    // Automatically open in browser
    let _ = Command::new("open")
        .arg(format!("http://127.0.0.1:{}", port))
        .spawn();

    for stream in listener.incoming() {
        if let Ok(mut stream) = stream {
            thread::spawn(move || {
                let mut buffer = [0; 2048];
                if let Ok(bytes_read) = stream.read(&mut buffer) {
                    let request_str = String::from_utf8_lossy(&buffer[..bytes_read]);
                    if request_str.starts_with("GET /api/metrics") {
                        match get_aggregated_metrics() {
                            Ok(json) => {
                                let response = format!(
                                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                                    json.len(),
                                    json
                                );
                                let _ = stream.write_all(response.as_bytes());
                            }
                            Err(e) => {
                                let err_msg = json!({
                                    "status": "error",
                                    "error": e.to_string()
                                }).to_string();
                                let response = format!(
                                    "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                                    err_msg.len(),
                                    err_msg
                                );
                                let _ = stream.write_all(response.as_bytes());
                            }
                        }
                    } else if request_str.starts_with("GET /") {
                        let html = get_dashboard_html();
                        let response = format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                            html.len(),
                            html
                        );
                        let _ = stream.write_all(response.as_bytes());
                    } else {
                        let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                        let _ = stream.write_all(response.as_bytes());
                    }
                }
            });
        }
    }
    Ok(())
}

fn get_aggregated_metrics() -> Result<String> {
    let config = McloudConfig::load()?;
    let results = Arc::new(Mutex::new(HashMap::new()));
    let mut handles = Vec::new();

    for (node_name, node_config) in config.node.clone() {
        let results = Arc::clone(&results);
        let handle = thread::spawn(move || {
            let metric_res = query_node_metrics(&node_config);
            let mut lock = results.lock().unwrap();
            match metric_res {
                Ok(metrics_json) => {
                    lock.insert(node_name, metrics_json);
                }
                Err(e) => {
                    lock.insert(
                        node_name,
                        json!({
                            "status": "offline",
                            "error": e.to_string()
                        }),
                    );
                }
            }
        });
        handles.push(handle);
    }

    for handle in handles {
        let _ = handle.join();
    }

    let map = results.lock().unwrap();
    let json_str = serde_json::to_string(&*map)?;
    Ok(json_str)
}

fn query_node_metrics(node_config: &NodeConfig) -> Result<serde_json::Value> {
    let mut session = SshSession::new(node_config)?;
    let response = session.send_request(&Request::GetMetrics)?;
    match response {
        mcloud_common::protocol::Response::Metrics {
            hostname,
            cpu_usage,
            gpu_usage,
            temperature_c,
            memory_used,
            memory_total,
            storage_used,
            storage_total,
            power_watts,
            active_tasks,
        } => Ok(json!({
            "status": "online",
            "hostname": hostname,
            "cpu_usage": cpu_usage,
            "gpu_usage": gpu_usage,
            "temperature_c": temperature_c,
            "memory_used": memory_used,
            "memory_total": memory_total,
            "storage_used": storage_used,
            "storage_total": storage_total,
            "power_watts": power_watts,
            "active_tasks": active_tasks
        })),
        mcloud_common::protocol::Response::Error { message } => {
            anyhow::bail!("{message}")
        }
        _ => anyhow::bail!("unexpected response from agent"),
    }
}

fn get_dashboard_html() -> String {
    r#"<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>mcloud Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #080a10;
            --card-bg: rgba(18, 22, 33, 0.65);
            --card-border: rgba(255, 255, 255, 0.08);
            --text-main: #f3f4f6;
            --text-muted: #9ca3af;
            --glow-color: rgba(0, 242, 254, 0.25);
            --success: #10b981;
            --danger: #ef4444;
            --primary: #4facfe;
            --primary-glow: rgba(79, 172, 254, 0.3);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            min-height: 100vh;
            padding: 2.5rem 1.5rem;
            background-image: 
                radial-gradient(at 10% 20%, rgba(79, 172, 254, 0.08) 0px, transparent 50%),
                radial-gradient(at 90% 80%, rgba(0, 242, 254, 0.06) 0px, transparent 50%);
            background-attachment: fixed;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 3rem;
            border-bottom: 1px solid var(--card-border);
            padding-bottom: 1.5rem;
        }

        .logo-section h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 2.2rem;
            font-weight: 800;
            background: linear-gradient(135deg, #00f2fe 0%, #4facfe 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            letter-spacing: -0.5px;
            margin-bottom: 0.25rem;
        }

        .logo-section p {
            font-size: 0.9rem;
            color: var(--text-muted);
        }

        .header-stats {
            display: flex;
            gap: 1.5rem;
            font-size: 0.9rem;
        }

        .stat-badge {
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--card-border);
            padding: 0.5rem 1rem;
            border-radius: 9999px;
            backdrop-filter: blur(8px);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .pulse-dot {
            width: 8px;
            height: 8px;
            background-color: var(--success);
            border-radius: 50%;
            display: inline-block;
            box-shadow: 0 0 8px var(--success);
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
            70% { transform: scale(1); box-shadow: 0 0 0 6px rgba(16, 185, 129, 0); }
            100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 2rem;
        }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 18px;
            padding: 2rem;
            backdrop-filter: blur(16px);
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }

        .card:hover {
            transform: translateY(-6px) scale(1.01);
            border-color: rgba(0, 242, 254, 0.25);
            box-shadow: 0 12px 40px 0 rgba(0, 242, 254, 0.12);
        }

        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            opacity: 0.8;
        }

        .card.offline::before {
            background: var(--danger);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 1.8rem;
        }

        .node-title-group h2 {
            font-family: 'Outfit', sans-serif;
            font-size: 1.4rem;
            font-weight: 700;
            margin-bottom: 0.15rem;
            letter-spacing: -0.3px;
        }

        .node-hostname {
            font-size: 0.8rem;
            color: var(--text-muted);
            font-family: monospace;
        }

        .status-pill {
            padding: 0.3rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            display: flex;
            align-items: center;
            gap: 0.4rem;
            border: 1px solid rgba(255,255,255,0.05);
        }

        .status-pill.online {
            background: rgba(16, 185, 129, 0.1);
            color: var(--success);
        }

        .status-pill.offline {
            background: rgba(239, 68, 68, 0.1);
            color: var(--danger);
        }

        .status-dot {
            width: 6px;
            height: 6px;
            border-radius: 50%;
            display: inline-block;
        }

        .status-pill.online .status-dot { background-color: var(--success); box-shadow: 0 0 6px var(--success); }
        .status-pill.offline .status-dot { background-color: var(--danger); box-shadow: 0 0 6px var(--danger); }

        .metrics-list {
            display: flex;
            flex-direction: column;
            gap: 1.25rem;
            margin-bottom: 1.5rem;
        }

        .metric-row {
            display: flex;
            flex-direction: column;
            gap: 0.4rem;
        }

        .metric-meta {
            display: flex;
            justify-content: space-between;
            font-size: 0.85rem;
        }

        .metric-label {
            color: var(--text-muted);
            font-weight: 500;
        }

        .metric-value {
            font-weight: 600;
            font-variant-numeric: tabular-nums;
        }

        .progress-container {
            height: 8px;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 4px;
            overflow: hidden;
            border: 1px solid rgba(255,255,255,0.02);
        }

        .progress-bar {
            height: 100%;
            border-radius: 4px;
            width: 0%;
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            box-shadow: 0 0 10px rgba(0, 242, 254, 0.3);
            transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1rem;
            border-top: 1px solid var(--card-border);
            padding-top: 1.5rem;
            margin-top: 1.5rem;
        }

        .info-item {
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
        }

        .info-label {
            font-size: 0.75rem;
            color: var(--text-muted);
            margin-bottom: 0.25rem;
            font-weight: 500;
        }

        .info-value {
            font-family: 'Outfit', sans-serif;
            font-size: 1.05rem;
            font-weight: 600;
            color: var(--text-main);
        }

        .error-panel {
            background: rgba(239, 68, 68, 0.05);
            border: 1px solid rgba(239, 68, 68, 0.2);
            padding: 1rem;
            border-radius: 12px;
            font-size: 0.85rem;
            color: #fca5a5;
            line-height: 1.4;
            font-family: monospace;
            margin-top: 1rem;
            word-break: break-all;
        }

        .loader-wrapper {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 200px;
            grid-column: 1 / -1;
        }

        .loader {
            width: 40px;
            height: 40px;
            border: 3px solid rgba(0, 242, 254, 0.1);
            border-radius: 50%;
            border-top-color: var(--primary);
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .empty-state {
            text-align: center;
            padding: 4rem 2rem;
            grid-column: 1 / -1;
            color: var(--text-muted);
        }

        .empty-state h3 {
            font-family: 'Outfit', sans-serif;
            font-size: 1.4rem;
            margin-bottom: 0.5rem;
            color: var(--text-main);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo-section">
                <h1>mcloud dashboard</h1>
                <p>Apple Multi-Node Compute & Telemetry Plane</p>
            </div>
            <div class="header-stats">
                <div class="stat-badge" id="online-badge">
                    <span class="pulse-dot"></span>
                    <span id="active-nodes-text">Updating...</span>
                </div>
                <div class="stat-badge" id="last-refreshed">
                    Refreshed: Just now
                </div>
            </div>
        </header>

        <main class="grid" id="nodes-grid">
            <div class="loader-wrapper" id="grid-loader">
                <div class="loader"></div>
            </div>
        </main>
    </div>

    <script>
        const nodesGrid = document.getElementById('nodes-grid');
        const activeNodesText = document.getElementById('active-nodes-text');
        const lastRefreshed = document.getElementById('last-refreshed');

        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
        }

        async function fetchMetrics() {
            try {
                const response = await fetch('/api/metrics');
                if (!response.ok) throw new Error('API server returned error');
                const data = await response.json();
                renderDashboard(data);
            } catch (err) {
                console.error("Failed to fetch node metrics:", err);
            }
        }

        function renderDashboard(data) {
            const keys = Object.keys(data);
            if (keys.length === 0) {
                nodesGrid.innerHTML = `
                    <div class="empty-state">
                        <h3>No nodes configured</h3>
                        <p>Configure nodes in your <code>~/.mcloud/config.toml</code> to get started.</p>
                    </div>
                `;
                activeNodesText.textContent = "0 Nodes Configured";
                return;
            }

            let html = '';
            let onlineCount = 0;

            keys.sort().forEach(nodeName => {
                const node = data[nodeName];
                const isOnline = node.status === 'online';

                if (isOnline) {
                    onlineCount++;
                    const cpu = node.cpu_usage || 0;
                    const gpu = node.gpu_usage || 0;
                    const memUsed = node.memory_used || 0;
                    const memTotal = node.memory_total || 1;
                    const memPct = (memUsed / memTotal * 100).toFixed(1);
                    const diskUsed = node.storage_used || 0;
                    const diskTotal = node.storage_total || 1;
                    const diskPct = (diskUsed / diskTotal * 100).toFixed(1);
                    const temp = node.temperature_c !== null ? `${node.temperature_c.toFixed(0)}°C` : 'N/A';
                    const power = node.power_watts !== null ? `${node.power_watts.toFixed(1)}W` : 'N/A';

                    html += `
                        <div class="card">
                            <div class="card-header">
                                <div class="node-title-group">
                                    <h2>${nodeName}</h2>
                                    <div class="node-hostname">${node.hostname || ''}</div>
                                </div>
                                <div class="status-pill online">
                                    <span class="status-dot"></span>
                                    online
                                </div>
                            </div>
                            <div class="metrics-list">
                                <div class="metric-row">
                                    <div class="metric-meta">
                                        <span class="metric-label">CPU Usage</span>
                                        <span class="metric-value">${cpu.toFixed(1)}%</span>
                                    </div>
                                    <div class="progress-container">
                                        <div class="progress-bar" style="width: ${cpu}%"></div>
                                    </div>
                                </div>
                                <div class="metric-row">
                                    <div class="metric-meta">
                                        <span class="metric-label">GPU Utilization</span>
                                        <span class="metric-value">${gpu.toFixed(1)}%</span>
                                    </div>
                                    <div class="progress-container">
                                        <div class="progress-bar" style="width: ${gpu}%; background: linear-gradient(90deg, #ec4899, #f43f5e)"></div>
                                    </div>
                                </div>
                                <div class="metric-row">
                                    <div class="metric-meta">
                                        <span class="metric-label">Memory</span>
                                        <span class="metric-value">${memPct}% (${formatBytes(memUsed)} / ${formatBytes(memTotal)})</span>
                                    </div>
                                    <div class="progress-container">
                                        <div class="progress-bar" style="width: ${memPct}%; background: linear-gradient(90deg, #8b5cf6, #d946ef)"></div>
                                    </div>
                                </div>
                                <div class="metric-row">
                                    <div class="metric-meta">
                                        <span class="metric-label">Storage</span>
                                        <span class="metric-value">${diskPct}% (${formatBytes(diskUsed)} / ${formatBytes(diskTotal)})</span>
                                    </div>
                                    <div class="progress-container">
                                        <div class="progress-bar" style="width: ${diskPct}%; background: linear-gradient(90deg, #f59e0b, #eab308)"></div>
                                    </div>
                                </div>
                            </div>
                            <div class="info-grid">
                                <div class="info-item">
                                    <span class="info-label">Power</span>
                                    <span class="info-value">${power}</span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">Temp</span>
                                    <span class="info-value">${temp}</span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">Active Tasks</span>
                                    <span class="info-value">${node.active_tasks || 0}</span>
                                </div>
                            </div>
                        </div>
                    `;
                } else {
                    html += `
                        <div class="card offline">
                            <div class="card-header">
                                <div class="node-title-group">
                                    <h2>${nodeName}</h2>
                                    <div class="node-hostname">Offline or Unreachable</div>
                                </div>
                                <div class="status-pill offline">
                                    <span class="status-dot"></span>
                                    offline
                                </div>
                            </div>
                            <div class="error-panel">
                                Error: ${node.error || 'Connection failed'}
                            </div>
                        </div>
                    `;
                }
            });

            nodesGrid.innerHTML = html;
            activeNodesText.textContent = `${onlineCount} / ${keys.length} Nodes Online`;
            
            const now = new Date();
            lastRefreshed.textContent = `Refreshed: ${now.toLocaleTimeString()}`;
        }

        // Poll every 3 seconds
        setInterval(fetchMetrics, 3000);
        // Initial fetch
        fetchMetrics();
    </script>
</body>
</html>
"#
    .to_string()
}
