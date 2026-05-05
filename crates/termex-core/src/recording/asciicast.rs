use serde::{Deserialize, Serialize};

/// Asciicast v2 header.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AsciicastHeader {
    pub version: u32,
    pub width: u32,
    pub height: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub timestamp: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env: Option<serde_json::Value>,
}

impl AsciicastHeader {
    /// Creates a new v2 header.
    pub fn new(width: u32, height: u32, title: Option<String>) -> Self {
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .ok();

        Self {
            version: 2,
            width,
            height,
            timestamp,
            title,
            env: None,
        }
    }
}

/// A single event in an asciicast recording.
/// Format: `[time, event_type, data]`
/// time: seconds since recording start (f64)
/// event_type: "o" for output, "i" for input
/// data: the text data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AsciicastEvent(pub f64, pub String, pub String);

impl AsciicastEvent {
    /// Creates an output event.
    pub fn output(time: f64, data: &str) -> Self {
        Self(time, "o".into(), data.to_string())
    }

    /// Creates an input event.
    pub fn input(time: f64, data: &str) -> Self {
        Self(time, "i".into(), data.to_string())
    }
}

/// Parsed asciicast file (header + events).
#[derive(Debug)]
pub struct AsciicastFile {
    pub header: AsciicastHeader,
    pub events: Vec<AsciicastEvent>,
}

impl AsciicastFile {
    /// Parses an asciicast v2 file from lines.
    pub fn parse(content: &str) -> Result<Self, super::RecordingError> {
        let mut lines = content.lines();
        let header_line = lines.next().ok_or_else(|| {
            super::RecordingError::Json(serde_json::Error::io(std::io::Error::new(
                std::io::ErrorKind::UnexpectedEof,
                "empty file",
            )))
        })?;
        let header: AsciicastHeader = serde_json::from_str(header_line)?;

        let mut events = Vec::new();
        for line in lines {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            let event: AsciicastEvent = serde_json::from_str(line)?;
            events.push(event);
        }

        Ok(Self { header, events })
    }

    /// Serializes to asciicast v2 format (one JSON object per line).
    pub fn serialize(&self) -> Result<String, super::RecordingError> {
        let mut output = serde_json::to_string(&self.header)?;
        output.push('\n');
        for event in &self.events {
            output.push_str(&serde_json::to_string(event)?);
            output.push('\n');
        }
        Ok(output)
    }

    /// Returns the total duration of the recording in seconds.
    pub fn duration(&self) -> f64 {
        self.events.last().map(|e| e.0).unwrap_or(0.0)
    }
}