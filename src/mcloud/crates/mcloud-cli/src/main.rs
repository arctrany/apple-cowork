mod commands;
mod config;
mod ssh;

use clap::{Parser, Subcommand};

/// mcloud — Offload compute tasks to remote Apple Silicon nodes
#[derive(Parser)]
#[command(name = "mcloud", version, about, long_about = None)]
#[command(propagate_version = true)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Execute a command on a remote compute node.
    ///
    /// Syncs your project files, runs the command remotely, and streams output.
    Run {
        /// The command to execute (e.g., "cargo build --release").
        #[arg(required = true)]
        command: Vec<String>,

        /// Target node name (from ~/.mcloud/config.toml).
        #[arg(short, long)]
        node: Option<String>,

        /// Skip file sync before execution.
        #[arg(long)]
        no_sync: bool,

        /// Project name override (defaults to current directory name).
        #[arg(short, long)]
        project: Option<String>,
    },

    /// View logs from a remote task.
    Logs {
        /// Task ID to retrieve logs for.
        task_id: String,

        /// Target node name.
        #[arg(short, long)]
        node: Option<String>,

        /// Show only the last N lines.
        #[arg(short, long)]
        tail: Option<usize>,

        /// Follow log output (like tail -f).
        #[arg(short, long)]
        follow: bool,
    },

    /// List tasks on a remote node.
    Status {
        /// Target node name.
        #[arg(short, long)]
        node: Option<String>,
    },

    /// Manually sync files to a remote node.
    Sync {
        /// Target node name.
        #[arg(short, long)]
        node: Option<String>,

        /// Project name override.
        #[arg(short, long)]
        project: Option<String>,
    },

    /// Kill a running task on a remote node.
    Kill {
        /// Task ID to kill.
        task_id: String,

        /// Target node name.
        #[arg(short, long)]
        node: Option<String>,
    },

    /// Show remote node information (power, tasks, etc.).
    Info {
        /// Target node name.
        #[arg(short, long)]
        node: Option<String>,
    },

    /// Diagnose connectivity and configuration.
    Doctor {
        /// Target node name (checks all configured nodes if omitted).
        #[arg(short, long)]
        node: Option<String>,
    },

    /// List configured nodes.
    Nodes,

    /// Generate a default configuration file.
    Init,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Run {
            command,
            node,
            no_sync,
            project,
        } => commands::run::execute(command, node, no_sync, project),

        Commands::Logs {
            task_id,
            node,
            tail,
            follow,
        } => commands::logs::execute(&task_id, node, tail, follow),

        Commands::Status { node } => commands::status::execute(node),

        Commands::Sync { node, project } => commands::sync::execute(node, project),

        Commands::Kill { task_id, node } => commands::kill::execute(&task_id, node),

        Commands::Info { node } => commands::info::execute(node),

        Commands::Doctor { node } => commands::doctor::execute(node),

        Commands::Nodes => commands::nodes::execute(),

        Commands::Init => commands::init::execute(),
    }
}
