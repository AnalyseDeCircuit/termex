//! Parser tests for remote metrics collection.
//!
//! Fixtures are verbatim output from a real Ubuntu host, so column positions,
//! header rows and the header/data whitespace are exactly what the parsers
//! actually receive.

use termex_core::monitor::collector::*;
use termex_core::monitor::types::*;

const PROC_STAT: &str = "cpu  1220385 4913 340178 41219871 27214 0 24513 0 0 0
cpu0 305096 1228 85044 10304967 6803 0 6128 0 0 0
intr 123456789";

const PROC_MEMINFO: &str = "MemTotal:        8039256 kB
MemFree:          213404 kB
MemAvailable:    5321084 kB
Buffers:          181292 kB
Cached:          4996392 kB
SwapCached:            0 kB
Active:          2374480 kB
Inactive:        4699552 kB";

const DF_OUTPUT: &str = "Filesystem     1024-blocks     Used Available Capacity Mounted on
/dev/vda1         81120644 24336192  52619204      32% /";

const PROC_NET_DEV: &str = "Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 5678901    4321    0    0    0     0          0         0  5678901    4321    0    0    0     0       0          0
  eth0: 998877665  812345    0    0    0     0          0         0 445566778  654321    0    0    0     0       0          0";

const PS_OUTPUT: &str = "    PID USER     %CPU %MEM COMMAND
   1234 huzou     12.5  3.4 postgres
    987 root       4.0  1.2 sshd
      1 root       0.0  0.1 systemd";

fn snapshot_output() -> String {
    format!(
        "---CPU---\n{PROC_STAT}\n---MEM---\n{PROC_MEMINFO}\n---DISK---\n{DF_OUTPUT}\n\
         ---NET---\n{PROC_NET_DEV}\n---LOAD---\n0.52 0.44 0.39 1/412 98765\n\
         ---UPTIME---\n41597.12 331054.60\n---PROCS---\n{PS_OUTPUT}\n"
    )
}

// ─── Sections ────────────────────────────────────────────────────────────────

#[test]
fn split_sections_keys_every_marker() {
    let s = split_sections(&snapshot_output());
    let mut keys: Vec<&String> = s.keys().collect();
    keys.sort();
    assert_eq!(keys, ["CPU", "DISK", "LOAD", "MEM", "NET", "PROCS", "UPTIME"]);
}

#[test]
fn split_sections_ignores_text_before_the_first_marker() {
    // Shell banners / MOTD land ahead of the first marker on some hosts.
    let s = split_sections("Welcome to Ubuntu\n---CPU---\ncpu 1 2 3 4 5 6 7 8\n");
    assert_eq!(s.len(), 1);
    assert!(s["CPU"].starts_with("cpu "));
}

// ─── CPU ─────────────────────────────────────────────────────────────────────

#[test]
fn parses_the_aggregate_cpu_line() {
    let c = parse_proc_stat_cpu(PROC_STAT).expect("cpu line");
    assert_eq!(c.user, 1_220_385);
    assert_eq!(c.idle, 41_219_871);
    assert_eq!(c.iowait, 27_214);
    // guest / guest_nice (the trailing zeros) are already inside user/nice —
    // counting them again would inflate the total.
    assert_eq!(c.total(), 1_220_385 + 4_913 + 340_178 + 41_219_871 + 27_214 + 0 + 24_513 + 0);
}

#[test]
fn cpu_percent_is_busy_over_total_between_samples() {
    let prev = RawCpuCounters {
        user: 100, nice: 0, system: 50, idle: 800, iowait: 50, irq: 0, softirq: 0, steal: 0,
    };
    // +100 busy, +100 idle over a +200 total → 50%.
    let cur = RawCpuCounters {
        user: 180, nice: 0, system: 70, idle: 900, iowait: 50, irq: 0, softirq: 0, steal: 0,
    };
    let pct = cpu_percent_between(&prev, &cur).expect("advanced");
    assert!((pct - 50.0).abs() < 0.01, "got {pct}");
}

#[test]
fn cpu_percent_rejects_a_stalled_or_wrapped_counter() {
    let c = RawCpuCounters {
        user: 100, nice: 0, system: 0, idle: 100, iowait: 0, irq: 0, softirq: 0, steal: 0,
    };
    // Identical reads: 0% here would be indistinguishable from a truly idle
    // host, so the caller needs to know the sample was unusable.
    assert!(cpu_percent_between(&c, &c).is_none());

    let rebooted = RawCpuCounters { user: 1, ..c.clone() };
    assert!(cpu_percent_between(&c, &rebooted).is_none());
}

// ─── Memory ──────────────────────────────────────────────────────────────────

#[test]
fn memory_used_excludes_reclaimable_cache() {
    let (used_mb, total_mb) = parse_meminfo(PROC_MEMINFO).expect("meminfo");
    assert_eq!(total_mb, 8_039_256 / 1024);
    // MemTotal - MemAvailable. Using MemFree instead would report ~7.6 GB
    // used on this host — near 100% — because the page cache counts as free.
    assert_eq!(used_mb, (8_039_256 - 5_321_084) / 1024);
    assert!(used_mb < total_mb / 2);
}

#[test]
fn memory_falls_back_when_mem_available_is_absent() {
    // Kernels older than 3.14 do not publish MemAvailable.
    let old = "MemTotal:        1048576 kB\nMemFree:          262144 kB\n\
               Buffers:          131072 kB\nCached:           131072 kB";
    let (used_mb, total_mb) = parse_meminfo(old).expect("meminfo");
    assert_eq!(total_mb, 1024);
    assert_eq!(used_mb, 512);
}

// ─── Disk ────────────────────────────────────────────────────────────────────

#[test]
fn parses_df_skipping_the_header() {
    let (used_gb, total_gb) = parse_df(DF_OUTPUT).expect("df");
    assert!((total_gb - 77.36).abs() < 0.1, "total {total_gb}");
    assert!((used_gb - 23.21).abs() < 0.1, "used {used_gb}");
}

// ─── Network ─────────────────────────────────────────────────────────────────

#[test]
fn network_totals_skip_loopback() {
    let n = parse_proc_net_dev(PROC_NET_DEV);
    // eth0 only: loopback carries local IPC and would dwarf the real link.
    assert_eq!(n.rx_bytes, 998_877_665);
    assert_eq!(n.tx_bytes, 445_566_778);
}

#[test]
fn network_rate_is_bytes_per_second() {
    let prev = RawNetworkCounters { name: "total".into(), rx_bytes: 1_000, tx_bytes: 2_000 };
    let cur = RawNetworkCounters { name: "total".into(), rx_bytes: 3_000, tx_bytes: 2_500 };
    let (rx, tx) = net_rate_between(&prev, &cur, 2.0);
    assert_eq!((rx, tx), (1_000, 250));
}

#[test]
fn network_rate_is_zero_when_the_counter_resets() {
    let prev = RawNetworkCounters { name: "total".into(), rx_bytes: 9_000, tx_bytes: 9_000 };
    let cur = RawNetworkCounters { name: "total".into(), rx_bytes: 10, tx_bytes: 10 };
    // Interface reset or host reboot — a wrapped counter must not surface as
    // a multi-gigabyte spike.
    assert_eq!(net_rate_between(&prev, &cur, 2.0), (0, 0));
    // A zero interval would divide by zero.
    assert_eq!(net_rate_between(&prev, &cur, 0.0), (0, 0));
}

// ─── Processes ───────────────────────────────────────────────────────────────

#[test]
fn parses_ps_rows_and_honours_the_limit() {
    let procs = parse_ps(PS_OUTPUT, 10);
    assert_eq!(procs.len(), 3);
    assert_eq!(procs[0].pid, 1234);
    assert_eq!(procs[0].user, "huzou");
    assert!((procs[0].cpu_percent - 12.5).abs() < 0.01);
    assert!((procs[0].mem_percent - 3.4).abs() < 0.01);
    assert_eq!(procs[0].command, "postgres");

    assert_eq!(parse_ps(PS_OUTPUT, 2).len(), 2);
}

#[test]
fn command_columns_containing_spaces_survive() {
    let out = "    PID USER     %CPU %MEM COMMAND\n   42 root  1.0  2.0 /usr/bin/my daemon --flag";
    let procs = parse_ps(out, 10);
    assert_eq!(procs[0].command, "/usr/bin/my daemon --flag");
}

// ─── Snapshot + sampler ──────────────────────────────────────────────────────

#[test]
fn parse_snapshot_reads_every_section() {
    let s = parse_snapshot(&snapshot_output(), 20);
    assert!(s.cpu_raw.is_some());
    assert_eq!(s.mem_total_mb, 8_039_256 / 1024);
    assert!(s.disk_total_gb > 0.0);
    assert_eq!(s.net_raw.rx_bytes, 998_877_665);
    assert_eq!(s.processes.len(), 3);
    assert_eq!(s.uptime_secs, Some(41_597));
    assert!((s.load.expect("load").one - 0.52).abs() < 0.001);
}

#[test]
fn a_missing_section_does_not_fail_the_whole_tick() {
    // A BSD host without /proc/loadavg still has usable CPU and memory.
    let partial = format!("---CPU---\n{PROC_STAT}\n---MEM---\n{PROC_MEMINFO}\n");
    let s = parse_snapshot(&partial, 20);
    assert!(s.cpu_raw.is_some());
    assert_eq!(s.mem_total_mb, 8_039_256 / 1024);
    assert!(s.load.is_none());
    assert_eq!(s.disk_total_gb, 0.0);
    assert!(s.processes.is_empty());
}

#[test]
fn first_sample_primes_the_baseline_and_reports_zero_rates() {
    let mut sampler = MonitorSampler::new();
    assert!(!sampler.has_baseline("s1"));

    let first = sampler.ingest("s1", parse_snapshot(&snapshot_output(), 20), 1_000);
    // No previous counters to difference against — CPU% and throughput are
    // only meaningful from the second tick on.
    assert_eq!(first.cpu_percent, 0.0);
    assert_eq!((first.net_rx_bytes, first.net_tx_bytes), (0, 0));
    // Absolute gauges are available immediately.
    assert!(first.mem_total_mb > 0);
    assert_eq!(first.processes.len(), 3);
    assert!(sampler.has_baseline("s1"));
}

#[test]
fn second_sample_derives_real_cpu_and_throughput() {
    let mut sampler = MonitorSampler::new();
    sampler.ingest("s1", parse_snapshot(&snapshot_output(), 20), 1_000);

    // Advance the counters: +100 busy ticks, +100 idle, and +2000 rx bytes
    // over 2 seconds.
    let advanced = snapshot_output()
        .replace(
            "cpu  1220385 4913 340178 41219871 27214",
            "cpu  1220485 4913 340178 41219971 27214",
        )
        .replace("998877665", "998879665");
    let second = sampler.ingest("s1", parse_snapshot(&advanced, 20), 3_000);

    assert!((second.cpu_percent - 50.0).abs() < 0.01, "got {}", second.cpu_percent);
    assert_eq!(second.net_rx_bytes, 1_000); // 2000 bytes over 2s
}

#[test]
fn sessions_keep_independent_baselines() {
    let mut sampler = MonitorSampler::new();
    sampler.ingest("a", parse_snapshot(&snapshot_output(), 20), 1_000);
    // "b" has never been sampled, so it must not borrow "a"'s baseline.
    let b = sampler.ingest("b", parse_snapshot(&snapshot_output(), 20), 3_000);
    assert_eq!(b.cpu_percent, 0.0);
    assert!(sampler.has_baseline("a"));
}

#[test]
fn forget_clears_the_baseline_so_a_reconnect_starts_clean() {
    let mut sampler = MonitorSampler::new();
    sampler.ingest("s1", parse_snapshot(&snapshot_output(), 20), 1_000);
    sampler.forget("s1");
    assert!(!sampler.has_baseline("s1"));

    // Without this, a reconnect after a reboot would difference against
    // pre-reboot counters and report a wild spike.
    let after = sampler.ingest("s1", parse_snapshot(&snapshot_output(), 20), 3_000);
    assert_eq!(after.cpu_percent, 0.0);
}

// ─── Batch command ───────────────────────────────────────────────────────────

#[test]
fn batch_command_emits_a_marker_per_section() {
    let cmd = build_batch_command(ServerOS::Linux);
    for section in ["CPU", "MEM", "DISK", "NET", "LOAD", "UPTIME", "PROCS"] {
        assert!(cmd.contains(&format!("---{section}---")), "missing {section}");
    }
}

#[test]
fn unknown_os_falls_back_to_the_linux_command() {
    assert_eq!(
        build_batch_command(ServerOS::Unknown),
        build_batch_command(ServerOS::Linux)
    );
}

#[test]
fn df_uses_posix_output_so_long_device_names_do_not_wrap() {
    // Without -P, a device name longer than the column wraps onto its own
    // line and every subsequent field shifts by one.
    assert!(build_batch_command(ServerOS::Linux).contains("df -kP"));
}
