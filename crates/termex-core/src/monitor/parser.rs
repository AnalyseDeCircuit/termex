use std::collections::HashMap;

use super::types::*;

/// Parses CPU metrics from raw command output.
///
/// Linux: computes delta from /proc/stat first line.
/// macOS: extracts percentages directly from `top -l` output.
pub fn parse_cpu(
    os: ServerOS,
    raw: &str,
    prev: Option<&RawCpuCounters>,
) -> (CpuMetrics, Option<RawCpuCounters>) {
    match os {
        ServerOS::Linux | ServerOS::FreeBSD | ServerOS::Unknown => parse_cpu_linux(raw, prev),
        ServerOS::MacOS => (parse_cpu_macos(raw), None),
    }
}

fn parse_cpu_linux(raw: &str, prev: Option<&RawCpuCounters>) -> (CpuMetrics, Option<RawCpuCounters>) {
    let parts: Vec<u64> = raw
        .split_whitespace()
        .skip(1) // skip "cpu" label
        .filter_map(|s| s.parse().ok())
        .collect();

    if parts.len() < 8 {
        return (CpuMetrics::default(), None);
    }

    let current = RawCpuCounters {
        user: parts[0],
        nice: parts[1],
        system: parts[2],
        idle: parts[3],
        iowait: parts[4],
        irq: parts[5],
        softirq: parts[6],
        steal: parts[7],
    };

    let cpu = if let Some(prev) = prev {
        let total_delta = current.total().saturating_sub(prev.total());
        if total_delta == 0 {
            CpuMetrics::default()
        } else {
            let idle_delta = current.idle_total().saturating_sub(prev.idle_total());
            let user_delta = (current.user + current.nice).saturating_sub(prev.user + prev.nice);
            let sys_delta = (current.system + current.irq + current.softirq)
                .saturating_sub(prev.system + prev.irq + prev.softirq);
            let iowait_delta = current.iowait.saturating_sub(prev.iowait);

            CpuMetrics {
                usage_percent: 100.0 * (total_delta - idle_delta) as f64 / total_delta as f64,
                user_percent: 100.0 * user_delta as f64 / total_delta as f64,
                system_percent: 100.0 * sys_delta as f64 / total_delta as f64,
                iowait_percent: 100.0 * iowait_delta as f64 / total_delta as f64,
                core_count: 0, // filled by collector from OsInfo
            }
        }
    } else {
        CpuMetrics::default()
    };

    (cpu, Some(current))
}

fn parse_cpu_macos(raw: &str) -> CpuMetrics {
    let mut user = 0.0;
    let mut sys = 0.0;
    let mut idle = 0.0;

    for part in raw.split(',') {
        let part = part.trim();
        if part.contains("user") {
            user = extract_percent(part);
        } else if part.contains("sys") {
            sys = extract_percent(part);
        } else if part.contains("idle") {
            idle = extract_percent(part);
        }
    }

    CpuMetrics {
        usage_percent: 100.0 - idle,
        user_percent: user,
        system_percent: sys,
        iowait_percent: 0.0,
        core_count: 0,
    }
}

/// Parses Memory metrics from raw command output.
pub fn parse_memory(os: ServerOS, raw: &str) -> MemoryMetrics {
    match os {
        ServerOS::Linux | ServerOS::Unknown => parse_memory_linux(raw),
        ServerOS::MacOS => parse_memory_macos(raw),
        ServerOS::FreeBSD => parse_memory_freebsd(raw),
    }
}

fn parse_memory_linux(raw: &str) -> MemoryMetrics {
    let mut fields: HashMap<String, u64> = HashMap::new();

    for line in raw.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 {
            let key = parts[0].trim_end_matches(':').to_string();
            if let Ok(val) = parts[1].parse::<u64>() {
                // /proc/meminfo values are in kB
                fields.insert(key, val * 1024);
            }
        }
    }

    let total = *fields.get("MemTotal").unwrap_or(&0);
    let available = *fields.get("MemAvailable").unwrap_or(&0);
    let swap_total = *fields.get("SwapTotal").unwrap_or(&0);
    let swap_free = *fields.get("SwapFree").unwrap_or(&0);

    let used = total.saturating_sub(available);
    let usage_percent = if total > 0 {
        100.0 * used as f64 / total as f64
    } else {
        0.0
    };

    MemoryMetrics {
        total_bytes: total,
        used_bytes: used,
        available_bytes: available,
        usage_percent,
        swap_total,
        swap_used: swap_total.saturating_sub(swap_free),
    }
}

fn parse_memory_macos(raw: &str) -> MemoryMetrics {
    let page_size: u64 = 4096;
    let mut active: u64 = 0;
    let mut wired: u64 = 0;
    let mut total: u64 = 0;

    let mut in_memsize = false;
    for line in raw.lines() {
        if line.contains("---MEMSIZE---") {
            in_memsize = true;
            continue;
        }
        if in_memsize {
            total = line.trim().parse().unwrap_or(0);
            in_memsize = false;
            continue;
        }
        if line.contains("Pages active") {
            active = extract_page_count(line);
        } else if line.contains("Pages wired") {
            wired = extract_page_count(line);
        }
    }

    let used = (active + wired) * page_size;
    let available = total.saturating_sub(used);
    let usage_percent = if total > 0 {
        100.0 * used as f64 / total as f64
    } else {
        0.0
    };

    MemoryMetrics {
        total_bytes: total,
        used_bytes: used,
        available_bytes: available,
        usage_percent,
        swap_total: 0,
        swap_used: 0,
    }
}

fn parse_memory_freebsd(raw: &str) -> MemoryMetrics {
    // sysctl output: 4 lines (physmem, usermem, v_free_count, v_page_size)
    let values: Vec<u64> = raw
        .lines()
        .filter_map(|l| l.trim().parse().ok())
        .collect();

    if values.len() < 4 {
        return MemoryMetrics::default();
    }

    let total = values[0];
    let free_pages = values[2];
    let page_size = values[3];
    let free_bytes = free_pages * page_size;
    let available = free_bytes;
    let used = total.saturating_sub(available);

    let usage_percent = if total > 0 {
        100.0 * used as f64 / total as f64
    } else {
        0.0
    };

    MemoryMetrics {
        total_bytes: total,
        used_bytes: used,
        available_bytes: available,
        usage_percent,
        swap_total: 0,
        swap_used: 0,
    }
}

/// Parses Disk metrics from `df` output.
pub fn parse_disk(os: ServerOS, raw: &str) -> Vec<DiskMetrics> {
    let mut disks = Vec::new();

    for line in raw.lines().skip(1) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 4 {
            continue;
        }

        let (mount, total, used, avail) = match os {
            ServerOS::MacOS => {
                if parts.len() < 6 {
                    continue;
                }
                let block_size: u64 = 512;
                (
                    parts[parts.len() - 1].to_string(),
                    parts[1].parse::<u64>().unwrap_or(0) * block_size,
                    parts[2].parse::<u64>().unwrap_or(0) * block_size,
                    parts[3].parse::<u64>().unwrap_or(0) * block_size,
                )
            }
            _ => (
                parts[0].to_string(),
                parts[1].parse::<u64>().unwrap_or(0),
                parts[2].parse::<u64>().unwrap_or(0),
                parts[3].parse::<u64>().unwrap_or(0),
            ),
        };

        let usage_percent = if total > 0 {
            100.0 * used as f64 / total as f64
        } else {
            0.0
        };

        disks.push(DiskMetrics {
            mount_point: mount,
            total_bytes: total,
            used_bytes: used,
            available_bytes: avail,
            usage_percent,
        });
    }

    disks
}

/// Parses Network metrics with delta rate calculation.
pub fn parse_network(
    os: ServerOS,
    raw: &str,
    prev: &HashMap<String, RawNetworkCounters>,
    elapsed_secs: f64,
) -> (NetworkMetrics, HashMap<String, RawNetworkCounters>) {
    let raw_counters = match os {
        ServerOS::Linux | ServerOS::FreeBSD | ServerOS::Unknown => parse_net_linux(raw),
        ServerOS::MacOS => parse_net_macos(raw),
    };

    let mut interfaces = Vec::new();
    let mut new_counters = HashMap::new();

    for counter in &raw_counters {
        let (rx_rate, tx_rate) = if let Some(prev_counter) = prev.get(&counter.name) {
            let rx_delta = counter.rx_bytes.saturating_sub(prev_counter.rx_bytes);
            let tx_delta = counter.tx_bytes.saturating_sub(prev_counter.tx_bytes);
            if elapsed_secs > 0.0 {
                (rx_delta as f64 / elapsed_secs, tx_delta as f64 / elapsed_secs)
            } else {
                (0.0, 0.0)
            }
        } else {
            (0.0, 0.0)
        };

        interfaces.push(NetworkInterface {
            name: counter.name.clone(),
            rx_bytes_per_sec: rx_rate,
            tx_bytes_per_sec: tx_rate,
            rx_total: counter.rx_bytes,
            tx_total: counter.tx_bytes,
        });

        new_counters.insert(counter.name.clone(), counter.clone());
    }

    (NetworkMetrics { interfaces }, new_counters)
}

/// Parses Load Average.
pub fn parse_load(os: ServerOS, raw: &str) -> LoadAverage {
    match os {
        ServerOS::MacOS | ServerOS::FreeBSD => {
            // "{ 0.52 0.38 0.25 }"
            let cleaned = raw.replace(['{', '}'], "");
            let parts: Vec<f64> = cleaned
                .split_whitespace()
                .filter_map(|s| s.parse().ok())
                .collect();
            LoadAverage {
                one: *parts.first().unwrap_or(&0.0),
                five: *parts.get(1).unwrap_or(&0.0),
                fifteen: *parts.get(2).unwrap_or(&0.0),
            }
        }
        _ => {
            // "0.52 0.38 0.25 1/234 12345"
            let parts: Vec<f64> = raw
                .split_whitespace()
                .take(3)
                .filter_map(|s| s.parse().ok())
                .collect();
            LoadAverage {
                one: *parts.first().unwrap_or(&0.0),
                five: *parts.get(1).unwrap_or(&0.0),
                fifteen: *parts.get(2).unwrap_or(&0.0),
            }
        }
    }
}

/// Parses Uptime.
pub fn parse_uptime(os: ServerOS, raw: &str) -> f64 {
    match os {
        ServerOS::MacOS | ServerOS::FreeBSD => {
            // "{ sec = 1700000000, usec = 0 } ..."
            if let Some(sec_str) = raw.split("sec = ").nth(1) {
                if let Some(sec) = sec_str
                    .split(',')
                    .next()
                    .and_then(|s| s.trim().parse::<i64>().ok())
                {
                    let now = time::OffsetDateTime::now_utc().unix_timestamp();
                    return (now - sec) as f64;
                }
            }
            0.0
        }
        _ => {
            // "123456.78 234567.89"
            raw.split_whitespace()
                .next()
                .and_then(|s| s.parse().ok())
                .unwrap_or(0.0)
        }
    }
}

/// Parses process list from `ps aux` output.
pub fn parse_processes(raw: &str) -> Vec<ProcessInfo> {
    raw.lines()
        .skip(1) // skip header
        .filter_map(|line| {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() < 11 {
                return None;
            }
            Some(ProcessInfo {
                pid: parts[1].parse().unwrap_or(0),
                user: parts[0].to_string(),
                cpu_percent: parts[2].parse().unwrap_or(0.0),
                mem_percent: parts[3].parse().unwrap_or(0.0),
                command: parts[10..].join(" "),
            })
        })
        .collect()
}

// ──────── Internal helpers ────────

fn parse_net_linux(raw: &str) -> Vec<RawNetworkCounters> {
    raw.lines()
        .filter_map(|line| {
            let line = line.trim();
            if !line.contains(':') {
                return None;
            }

            let (name, rest) = line.split_once(':')?;
            let name = name.trim();

            // Exclude loopback
            if name == "lo" {
                return None;
            }

            let parts: Vec<u64> = rest
                .split_whitespace()
                .filter_map(|s| s.parse().ok())
                .collect();

            if parts.len() < 10 {
                return None;
            }

            Some(RawNetworkCounters {
                name: name.to_string(),
                rx_bytes: parts[0],
                tx_bytes: parts[8],
            })
        })
        .collect()
}

fn parse_net_macos(raw: &str) -> Vec<RawNetworkCounters> {
    // netstat -ib: Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
    raw.lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() < 11 {
                return None;
            }
            let name = parts[0];
            if !name.starts_with("en") {
                return None;
            }
            Some(RawNetworkCounters {
                name: name.to_string(),
                rx_bytes: parts[6].parse().unwrap_or(0),
                tx_bytes: parts[9].parse().unwrap_or(0),
            })
        })
        .collect()
}

fn extract_percent(s: &str) -> f64 {
    s.split('%')
        .next()
        .and_then(|p| p.split_whitespace().last().and_then(|n| n.parse().ok()))
        .unwrap_or(0.0)
}

fn extract_page_count(line: &str) -> u64 {
    line.split(':')
        .nth(1)
        .and_then(|s| s.trim().trim_end_matches('.').parse().ok())
        .unwrap_or(0)
}
