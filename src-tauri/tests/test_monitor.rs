#![cfg(feature = "private")]

use std::collections::HashMap;

use termex_lib::monitor::parser;
use termex_lib::monitor::collector;
use termex_lib::monitor::types::*;

// ── CPU parsing ──

#[test]
fn test_parse_proc_stat_first_sample() {
    let raw = "cpu  374292 6380 168498 8737510 14498 0 7652 0 0 0";
    let (cpu, raw_cpu) = parser::parse_cpu(ServerOS::Linux, raw, None);
    assert_eq!(cpu.usage_percent, 0.0); // first sample, no delta
    assert!(raw_cpu.is_some());
    let raw_cpu = raw_cpu.unwrap();
    assert_eq!(raw_cpu.user, 374292);
    assert_eq!(raw_cpu.idle, 8737510);
}

#[test]
fn test_parse_proc_stat_delta() {
    let prev = RawCpuCounters {
        user: 100, nice: 0, system: 50, idle: 800, iowait: 10, irq: 0, softirq: 5, steal: 0,
    };
    let raw = "cpu  200 0 100 1600 20 0 10 0 0 0";
    let (cpu, _) = parser::parse_cpu(ServerOS::Linux, raw, Some(&prev));
    // total_delta = (200+0+100+1600+20+0+10+0) - (100+0+50+800+10+0+5+0) = 1930 - 965 = 965
    // idle_delta = (1600+20) - (800+10) = 810
    // usage = 100 * (965 - 810) / 965 ≈ 16.06%
    assert!((cpu.usage_percent - 16.06).abs() < 0.1);
}

#[test]
fn test_parse_proc_stat_invalid() {
    let raw = "garbage data";
    let (cpu, raw_cpu) = parser::parse_cpu(ServerOS::Linux, raw, None);
    assert_eq!(cpu.usage_percent, 0.0);
    assert!(raw_cpu.is_none());
}

#[test]
fn test_parse_macos_cpu() {
    let raw = "CPU usage: 12.50% user, 8.30% sys, 79.20% idle";
    let (cpu, _) = parser::parse_cpu(ServerOS::MacOS, raw, None);
    assert!((cpu.usage_percent - 20.8).abs() < 0.1);
    assert!((cpu.user_percent - 12.5).abs() < 0.1);
    assert!((cpu.system_percent - 8.3).abs() < 0.1);
}

// ── Memory parsing ──

#[test]
fn test_parse_meminfo() {
    let raw = "\
MemTotal:        8053636 kB
MemFree:         1234567 kB
MemAvailable:    5678901 kB
Buffers:          234567 kB
Cached:          2345678 kB
SwapCached:        12345 kB
SwapTotal:       2097148 kB
SwapFree:        2097148 kB";
    let mem = parser::parse_memory(ServerOS::Linux, raw);
    assert_eq!(mem.total_bytes, 8053636 * 1024);
    assert_eq!(mem.available_bytes, 5678901 * 1024);
    let expected_pct = 100.0 * (8053636 - 5678901) as f64 / 8053636.0;
    assert!((mem.usage_percent - expected_pct).abs() < 0.1);
    assert_eq!(mem.swap_used, 0);
}

#[test]
fn test_parse_macos_memory() {
    let raw = "\
Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                              100000.
Pages active:                            200000.
Pages inactive:                          150000.
Pages speculative:                        50000.
Pages throttled:                              0.
Pages wired down:                        100000.
---MEMSIZE---
17179869184";
    let mem = parser::parse_memory(ServerOS::MacOS, raw);
    assert_eq!(mem.total_bytes, 17179869184);
    assert_eq!(mem.used_bytes, 300000 * 4096);
}

#[test]
fn test_parse_freebsd_memory() {
    let raw = "\
17179869184
15032385536
234567
4096";
    let mem = parser::parse_memory(ServerOS::FreeBSD, raw);
    assert_eq!(mem.total_bytes, 17179869184);
    let free = 234567u64 * 4096;
    assert_eq!(mem.available_bytes, free);
    assert_eq!(mem.used_bytes, 17179869184 - free);
}

#[test]
fn test_parse_freebsd_memory_insufficient_data() {
    let raw = "123\n456";
    let mem = parser::parse_memory(ServerOS::FreeBSD, raw);
    assert_eq!(mem.total_bytes, 0); // default
}

// ── Disk parsing ──

#[test]
fn test_parse_df_linux() {
    let raw = "\
Mounted on              Size         Used        Avail
/              107374182400  64424509440 42949672960
/home          214748364800  75161927680 139586437120";
    let disks = parser::parse_disk(ServerOS::Linux, raw);
    assert_eq!(disks.len(), 2);
    assert_eq!(disks[0].mount_point, "/");
    assert_eq!(disks[0].total_bytes, 107374182400);
    assert!((disks[0].usage_percent - 60.0).abs() < 0.1);
    assert_eq!(disks[1].mount_point, "/home");
}

#[test]
fn test_parse_df_empty() {
    let raw = "Mounted on  Size  Used  Avail";
    let disks = parser::parse_disk(ServerOS::Linux, raw);
    assert_eq!(disks.len(), 0);
}

// ── Network parsing ──

#[test]
fn test_parse_proc_net_dev() {
    let raw = "\
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets
    lo:   12345678  123456    0    0    0     0          0         0  12345678  123456
  eth0: 987654321  654321    0    0    0     0          0         0 123456789  432100";
    let prev: HashMap<String, RawNetworkCounters> = HashMap::new();
    let (net, counters) = parser::parse_network(ServerOS::Linux, raw, &prev, 3.0);
    // lo should be filtered out
    assert_eq!(net.interfaces.len(), 1);
    assert_eq!(net.interfaces[0].name, "eth0");
    assert_eq!(net.interfaces[0].rx_total, 987654321);
    assert_eq!(net.interfaces[0].tx_total, 123456789);
    // First sample: rate is 0
    assert_eq!(net.interfaces[0].rx_bytes_per_sec, 0.0);
    assert_eq!(counters.len(), 1);
}

#[test]
fn test_network_rate_calculation() {
    let prev = HashMap::from([(
        "eth0".to_string(),
        RawNetworkCounters { name: "eth0".into(), rx_bytes: 1000000, tx_bytes: 500000 },
    )]);
    let raw = "\
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets
  eth0: 1300000  1000    0    0    0     0          0         0   800000   500";
    let (net, _) = parser::parse_network(ServerOS::Linux, raw, &prev, 3.0);
    // rx_rate = (1300000 - 1000000) / 3.0 = 100000
    assert!((net.interfaces[0].rx_bytes_per_sec - 100000.0).abs() < 1.0);
    // tx_rate = (800000 - 500000) / 3.0 = 100000
    assert!((net.interfaces[0].tx_bytes_per_sec - 100000.0).abs() < 1.0);
}

// ── Load Average parsing ──

#[test]
fn test_parse_loadavg_linux() {
    let raw = "0.52 0.38 0.25 1/234 12345";
    let load = parser::parse_load(ServerOS::Linux, raw);
    assert!((load.one - 0.52).abs() < 0.01);
    assert!((load.five - 0.38).abs() < 0.01);
    assert!((load.fifteen - 0.25).abs() < 0.01);
}

#[test]
fn test_parse_macos_loadavg() {
    let raw = "{ 1.23 0.98 0.67 }";
    let load = parser::parse_load(ServerOS::MacOS, raw);
    assert!((load.one - 1.23).abs() < 0.01);
    assert!((load.five - 0.98).abs() < 0.01);
}

#[test]
fn test_parse_loadavg_empty() {
    let raw = "";
    let load = parser::parse_load(ServerOS::Linux, raw);
    assert_eq!(load.one, 0.0);
}

// ── Process parsing ──

#[test]
fn test_parse_ps_aux() {
    let raw = "\
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root      1234 25.3  4.2 123456 34567 ?        Sl   10:00   1:23 nginx: worker process
app       5678 18.1 12.5 234567 56789 ?        Sl   09:00   2:34 node server.js --port 3000";
    let procs = parser::parse_processes(raw);
    assert_eq!(procs.len(), 2);
    assert_eq!(procs[0].pid, 1234);
    assert_eq!(procs[0].user, "root");
    assert!((procs[0].cpu_percent - 25.3).abs() < 0.1);
    assert_eq!(procs[0].command, "nginx: worker process");
    assert_eq!(procs[1].command, "node server.js --port 3000");
}

#[test]
fn test_parse_processes_empty() {
    let raw = "USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND";
    let procs = parser::parse_processes(raw);
    assert_eq!(procs.len(), 0);
}

// ── Uptime parsing ──

#[test]
fn test_parse_uptime_linux() {
    let raw = "123456.78 234567.89";
    let uptime = parser::parse_uptime(ServerOS::Linux, raw);
    assert!((uptime - 123456.78).abs() < 0.01);
}

#[test]
fn test_parse_uptime_empty() {
    let raw = "";
    let uptime = parser::parse_uptime(ServerOS::Linux, raw);
    assert_eq!(uptime, 0.0);
}

// ── Section splitting ──

#[test]
fn test_split_sections() {
    let output = "\
---CPU---
cpu  100 0 50 800 10 0 5 0
---MEM---
MemTotal: 8053636 kB
MemFree:  1234567 kB
---LOAD---
0.52 0.38 0.25 1/234 12345";
    let sections = collector::split_sections(output);
    assert_eq!(sections.len(), 3);
    assert!(sections.get("CPU").unwrap().contains("cpu"));
    assert!(sections.get("MEM").unwrap().contains("MemTotal"));
    assert!(sections.get("LOAD").unwrap().contains("0.52"));
}

#[test]
fn test_split_sections_empty() {
    let sections = collector::split_sections("");
    assert_eq!(sections.len(), 0);
}

#[test]
fn test_split_sections_no_markers() {
    let sections = collector::split_sections("just some text");
    assert_eq!(sections.len(), 0);
}

// ── Ring buffer (MetricsHistory) ──

fn make_metrics(ts: i64) -> SystemMetrics {
    SystemMetrics {
        timestamp: ts,
        cpu: CpuMetrics::default(),
        memory: MemoryMetrics::default(),
        disk: Vec::new(),
        network: NetworkMetrics { interfaces: Vec::new() },
        load: LoadAverage::default(),
        uptime_seconds: 0.0,
        top_cpu_processes: Vec::new(),
        top_mem_processes: Vec::new(),
    }
}

#[test]
fn test_ring_buffer_push_and_latest() {
    let mut buf = collector::MetricsHistory::new(3);
    assert!(buf.latest().is_none());

    buf.push(make_metrics(1));
    assert_eq!(buf.latest().unwrap().timestamp, 1);

    buf.push(make_metrics(2));
    buf.push(make_metrics(3));
    assert_eq!(buf.latest().unwrap().timestamp, 3);

    // Exceeds capacity, overwrites oldest
    buf.push(make_metrics(4));
    assert_eq!(buf.latest().unwrap().timestamp, 4);
}

#[test]
fn test_ring_buffer_capacity_one() {
    let mut buf = collector::MetricsHistory::new(1);
    buf.push(make_metrics(10));
    assert_eq!(buf.latest().unwrap().timestamp, 10);
    buf.push(make_metrics(20));
    assert_eq!(buf.latest().unwrap().timestamp, 20);
}

// ── Batch command building ──

#[test]
fn test_build_batch_command_linux() {
    let cmd = collector::build_batch_command(ServerOS::Linux);
    assert!(cmd.contains("---CPU---"));
    assert!(cmd.contains("/proc/stat"));
    assert!(cmd.contains("---MEM---"));
    assert!(cmd.contains("---NET---"));
    assert!(cmd.contains("---PROCS_CPU---"));
}

#[test]
fn test_build_batch_command_macos() {
    let cmd = collector::build_batch_command(ServerOS::MacOS);
    assert!(cmd.contains("top -l 1"));
    assert!(cmd.contains("vm_stat"));
    assert!(cmd.contains("sysctl"));
}

#[test]
fn test_build_batch_command_unknown_falls_back_to_linux() {
    let cmd_unknown = collector::build_batch_command(ServerOS::Unknown);
    let cmd_linux = collector::build_batch_command(ServerOS::Linux);
    assert_eq!(cmd_unknown, cmd_linux);
}

// ── RawCpuCounters ──

#[test]
fn test_raw_cpu_counters_total() {
    let c = RawCpuCounters {
        user: 100, nice: 10, system: 50, idle: 800, iowait: 20, irq: 5, softirq: 3, steal: 2,
    };
    assert_eq!(c.total(), 990);
    assert_eq!(c.idle_total(), 820); // idle + iowait
}
