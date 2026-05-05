use serde::Serialize;

/// Server operating system type, determines which command set to use for metric collection.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum ServerOS {
    Linux,
    MacOS,
    FreeBSD,
    Unknown,
}

/// A complete system metrics snapshot collected at a single point in time.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemMetrics {
    /// Collection timestamp (Unix milliseconds)
    pub timestamp: i64,
    /// CPU usage
    pub cpu: CpuMetrics,
    /// Memory usage
    pub memory: MemoryMetrics,
    /// Per-mount-point disk usage
    pub disk: Vec<DiskMetrics>,
    /// Network interface traffic
    pub network: NetworkMetrics,
    /// System load averages
    pub load: LoadAverage,
    /// System uptime in seconds
    pub uptime_seconds: f64,
    /// Top-N processes by CPU
    pub top_cpu_processes: Vec<ProcessInfo>,
    /// Top-N processes by memory
    pub top_mem_processes: Vec<ProcessInfo>,
}

/// CPU metrics.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuMetrics {
    /// Total usage (0-100)
    pub usage_percent: f64,
    /// User-space percentage
    pub user_percent: f64,
    /// Kernel-space percentage
    pub system_percent: f64,
    /// IO wait percentage
    pub iowait_percent: f64,
    /// CPU core count
    pub core_count: u32,
}

impl Default for CpuMetrics {
    fn default() -> Self {
        Self {
            usage_percent: 0.0,
            user_percent: 0.0,
            system_percent: 0.0,
            iowait_percent: 0.0,
            core_count: 0,
        }
    }
}

/// Memory metrics.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MemoryMetrics {
    /// Total physical memory (bytes)
    pub total_bytes: u64,
    /// Used memory (bytes)
    pub used_bytes: u64,
    /// Available memory (bytes)
    pub available_bytes: u64,
    /// Usage percentage (0-100)
    pub usage_percent: f64,
    /// Swap total (bytes)
    pub swap_total: u64,
    /// Swap used (bytes)
    pub swap_used: u64,
}

impl Default for MemoryMetrics {
    fn default() -> Self {
        Self {
            total_bytes: 0,
            used_bytes: 0,
            available_bytes: 0,
            usage_percent: 0.0,
            swap_total: 0,
            swap_used: 0,
        }
    }
}

/// Disk usage for a single mount point.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DiskMetrics {
    /// Mount point path (e.g., "/", "/home")
    pub mount_point: String,
    /// Total capacity (bytes)
    pub total_bytes: u64,
    /// Used (bytes)
    pub used_bytes: u64,
    /// Available (bytes)
    pub available_bytes: u64,
    /// Usage percentage (0-100)
    pub usage_percent: f64,
}

/// Network metrics across all interfaces.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NetworkMetrics {
    /// Per-interface traffic data
    pub interfaces: Vec<NetworkInterface>,
}

/// Traffic data for a single network interface.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NetworkInterface {
    /// Interface name (e.g., "eth0", "ens33")
    pub name: String,
    /// Receive rate (bytes/sec), computed from two samples
    pub rx_bytes_per_sec: f64,
    /// Transmit rate (bytes/sec)
    pub tx_bytes_per_sec: f64,
    /// Cumulative receive total (bytes)
    pub rx_total: u64,
    /// Cumulative transmit total (bytes)
    pub tx_total: u64,
}

/// System load averages.
#[derive(Debug, Clone, Serialize)]
pub struct LoadAverage {
    /// 1-minute average
    pub one: f64,
    /// 5-minute average
    pub five: f64,
    /// 15-minute average
    pub fifteen: f64,
}

impl Default for LoadAverage {
    fn default() -> Self {
        Self {
            one: 0.0,
            five: 0.0,
            fifteen: 0.0,
        }
    }
}

/// Process information from `ps aux`.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProcessInfo {
    /// Process ID
    pub pid: u32,
    /// Owning user
    pub user: String,
    /// CPU usage percentage
    pub cpu_percent: f64,
    /// Memory usage percentage
    pub mem_percent: f64,
    /// Command line
    pub command: String,
}

/// OS basic information (collected once on first connection, not updated periodically).
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OsInfo {
    /// Operating system type
    pub os_type: ServerOS,
    /// Kernel version (e.g., "Linux 5.15.0-91-generic x86_64")
    pub kernel: String,
    /// Distribution name (e.g., "Ubuntu 22.04.3 LTS")
    pub distro: String,
    /// CPU core count
    pub core_count: u32,
}

/// Raw network counters used internally for delta calculation.
#[derive(Debug, Clone)]
pub struct RawNetworkCounters {
    pub name: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

/// Raw CPU counters used internally for delta calculation.
#[derive(Debug, Clone)]
pub struct RawCpuCounters {
    pub user: u64,
    pub nice: u64,
    pub system: u64,
    pub idle: u64,
    pub iowait: u64,
    pub irq: u64,
    pub softirq: u64,
    pub steal: u64,
}

impl RawCpuCounters {
    /// Compute total ticks.
    pub fn total(&self) -> u64 {
        self.user + self.nice + self.system + self.idle
            + self.iowait + self.irq + self.softirq + self.steal
    }

    /// Compute idle ticks (idle + iowait).
    pub fn idle_total(&self) -> u64 {
        self.idle + self.iowait
    }
}
