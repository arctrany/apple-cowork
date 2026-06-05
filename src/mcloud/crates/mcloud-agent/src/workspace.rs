use anyhow::Result;
use mcloud_common::config::workspaces_dir;
use std::fs;

/// Ensure the workspace directory for a project exists.
pub fn ensure_workspace(project: &str) -> Result<std::path::PathBuf> {
    let workspace = workspaces_dir()?.join(project);
    fs::create_dir_all(&workspace)?;
    Ok(workspace)
}

/// List all project workspaces.
pub fn list_workspaces() -> Result<Vec<String>> {
    let dir = workspaces_dir()?;
    if !dir.exists() {
        return Ok(Vec::new());
    }

    let mut projects = Vec::new();
    for entry in fs::read_dir(&dir)? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
            projects.push(entry.file_name().to_string_lossy().to_string());
        }
    }

    Ok(projects)
}

/// Get disk usage of a workspace in bytes.
pub fn workspace_size(project: &str) -> Result<u64> {
    let workspace = workspaces_dir()?.join(project);
    if !workspace.exists() {
        return Ok(0);
    }
    dir_size(&workspace)
}

/// Recursively calculate directory size.
fn dir_size(path: &std::path::Path) -> Result<u64> {
    let mut total = 0;
    if path.is_dir() {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let ft = entry.file_type()?;
            if ft.is_file() {
                total += entry.metadata()?.len();
            } else if ft.is_dir() {
                total += dir_size(&entry.path())?;
            }
        }
    }
    Ok(total)
}
