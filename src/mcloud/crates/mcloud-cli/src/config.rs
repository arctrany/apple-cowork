use anyhow::Result;

/// Re-export for convenience.
#[allow(unused_imports)]
use mcloud_common::config::McloudConfig;

/// Resolve the project name from CLI arg or current directory name.
pub fn resolve_project_name(override_name: Option<String>) -> Result<String> {
    match override_name {
        Some(name) => Ok(name),
        None => {
            let cwd = std::env::current_dir()?;
            let dir_name = cwd
                .file_name()
                .ok_or_else(|| anyhow::anyhow!("cannot determine project name from cwd"))?
                .to_string_lossy()
                .to_string();
            Ok(dir_name)
        }
    }
}
