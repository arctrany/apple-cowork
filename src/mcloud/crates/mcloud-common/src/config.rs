use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

/// Top-level mcloud configuration, loaded from `~/.mcloud/config.toml`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct McloudConfig {
    /// Named compute nodes.
    #[serde(default)]
    pub node: HashMap<String, NodeConfig>,

    /// File synchronization settings.
    #[serde(default)]
    pub sync: SyncConfig,

    /// Default settings.
    #[serde(default)]
    pub defaults: DefaultsConfig,
}

/// Configuration for a single remote compute node.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeConfig {
    /// Tailscale hostname or IP address.
    pub host: String,

    /// SSH username on the remote node.
    #[serde(default = "default_user")]
    pub user: String,

    /// SSH port (default: 22).
    #[serde(default = "default_ssh_port")]
    pub port: u16,

    /// Path to SSH identity file (optional, uses system default).
    #[serde(default)]
    pub identity_file: Option<PathBuf>,
}

/// File synchronization configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncConfig {
    /// Patterns to exclude from rsync (e.g., "target/", "node_modules/").
    #[serde(default = "default_excludes")]
    pub excludes: Vec<String>,
}

/// Default settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefaultsConfig {
    /// Default node name to use when none is specified.
    #[serde(default)]
    pub node: Option<String>,
}

fn default_user() -> String {
    whoami::fallible::username().unwrap_or_else(|_| "mcloud".to_string())
}

fn default_ssh_port() -> u16 {
    22
}

fn default_excludes() -> Vec<String> {
    vec![
        "target/".to_string(),
        "node_modules/".to_string(),
        ".git/".to_string(),
        "*.o".to_string(),
        "*.pyc".to_string(),
        "__pycache__/".to_string(),
    ]
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self {
            excludes: default_excludes(),
        }
    }
}

impl Default for DefaultsConfig {
    fn default() -> Self {
        Self { node: None }
    }
}

impl McloudConfig {
    /// Load configuration from the default path `~/.mcloud/config.toml`.
    pub fn load() -> anyhow::Result<Self> {
        let config_path = Self::default_path()?;
        if config_path.exists() {
            let content = std::fs::read_to_string(&config_path)?;
            let config: McloudConfig = toml::from_str(&content)?;
            Ok(config)
        } else {
            // Return defaults if no config file exists
            Ok(Self {
                node: HashMap::new(),
                sync: SyncConfig::default(),
                defaults: DefaultsConfig::default(),
            })
        }
    }

    /// Get the default config file path.
    pub fn default_path() -> anyhow::Result<PathBuf> {
        let home = dirs::home_dir().ok_or_else(|| anyhow::anyhow!("cannot determine home directory"))?;
        Ok(home.join(".mcloud").join("config.toml"))
    }

    /// Resolve a node name to its configuration.
    /// If no name is given, uses the default node.
    pub fn resolve_node<'a>(&'a self, name: Option<&'a str>) -> anyhow::Result<(&'a str, &'a NodeConfig)> {
        let node_name = name
            .or(self.defaults.node.as_deref())
            .ok_or_else(|| {
                anyhow::anyhow!(
                    "no node specified and no default node configured.\n\
                     Set a default in ~/.mcloud/config.toml:\n\n\
                     [defaults]\n\
                     node = \"mac-mini\""
                )
            })?;

        let config = self.node.get(node_name).ok_or_else(|| {
            let available: Vec<&str> = self.node.keys().map(|s| s.as_str()).collect();
            anyhow::anyhow!(
                "node '{}' not found in config. Available nodes: {:?}",
                node_name,
                available
            )
        })?;

        Ok((node_name, config))
    }
}

/// Get the mcloud data directory (`~/.mcloud/`).
pub fn mcloud_home() -> anyhow::Result<PathBuf> {
    let home = dirs::home_dir().ok_or_else(|| anyhow::anyhow!("cannot determine home directory"))?;
    Ok(home.join(".mcloud"))
}

/// Get the tasks directory (`~/.mcloud/tasks/`).
pub fn tasks_dir() -> anyhow::Result<PathBuf> {
    Ok(mcloud_home()?.join("tasks"))
}

/// Get the workspaces directory (`~/.mcloud/workspaces/`).
pub fn workspaces_dir() -> anyhow::Result<PathBuf> {
    Ok(mcloud_home()?.join("workspaces"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = McloudConfig {
            node: HashMap::new(),
            sync: SyncConfig::default(),
            defaults: DefaultsConfig::default(),
        };
        assert!(config.sync.excludes.contains(&"target/".to_string()));
        assert!(config.defaults.node.is_none());
    }

    #[test]
    fn test_config_toml_parsing() {
        let toml_str = r#"
[node.mac-mini]
host = "mac-mini-m1"
user = "haowu"

[sync]
excludes = ["target/", ".git/"]

[defaults]
node = "mac-mini"
"#;
        let config: McloudConfig = toml::from_str(toml_str).unwrap();
        assert_eq!(config.node.len(), 1);
        assert_eq!(config.node["mac-mini"].host, "mac-mini-m1");
        assert_eq!(config.defaults.node.as_deref(), Some("mac-mini"));
    }
}
