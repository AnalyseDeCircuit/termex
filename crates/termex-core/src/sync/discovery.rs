use super::protocol::DiscoveredDevice;

/// Trait for mDNS device discovery.
///
/// The real mDNS-backed implementation lives in `termex-core-private`. OSS
/// builds only ship [`NoopDiscovery`] so the FRB bridge can compile and
/// `get_discovered_devices()` returns an empty list without errors.
pub trait DeviceDiscovery: Send + Sync {
    /// Starts advertising this device on the local network.
    fn start_advertising(&self, device_name: &str, port: u16) -> Result<(), String>;
    /// Stops the mDNS advertisement.
    fn stop_advertising(&self) -> Result<(), String>;
    /// Returns the current snapshot of discovered peer devices.
    fn discovered_devices(&self) -> Vec<DiscoveredDevice>;
}

/// No-op discovery used by OSS builds and when mDNS is unavailable.
pub struct NoopDiscovery;

impl DeviceDiscovery for NoopDiscovery {
    fn start_advertising(&self, _name: &str, _port: u16) -> Result<(), String> {
        Ok(())
    }
    fn stop_advertising(&self) -> Result<(), String> {
        Ok(())
    }
    fn discovered_devices(&self) -> Vec<DiscoveredDevice> {
        vec![]
    }
}
