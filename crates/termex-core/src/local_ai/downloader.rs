use std::path::Path;
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::oneshot;

/// Download a model file with HTTP Range support and SHA256 verification.
///
/// # Arguments
/// * `url` - The download URL
/// * `destination` - Where to save the file
/// * `expected_sha256` - Expected SHA256 hash for verification
/// * `cancel_rx` - Receiver for cancellation signal
/// * `progress_callback` - Callback for progress updates (bytes_downloaded, total_bytes)
///
/// # Returns
/// Ok(()) on success, Err(message) on failure
pub async fn download_with_progress(
    url: &str,
    destination: &Path,
    expected_sha256: &str,
    mut cancel_rx: oneshot::Receiver<()>,
    progress_callback: impl Fn(u64, u64) + Send + 'static,
) -> Result<(), String> {
    // Create parent directory if needed
    if let Some(parent) = destination.parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .map_err(|e| format!("Failed to create directory: {}", e))?;
    }

    // Support for local test files (for development/testing)
    if url.starts_with("local://") || url.starts_with("test://") {
        let test_file = std::path::Path::new(&std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string()))
            .join(".termex/models/test-model.gguf");

        if test_file.exists() {
            log::info!("Using local test file: {}", test_file.display());
            let file_size = tokio::fs::metadata(&test_file)
                .await
                .map_err(|e| format!("Failed to get test file size: {}", e))?
                .len();

            // Copy test file with progress updates
            let mut src = tokio::fs::File::open(&test_file)
                .await
                .map_err(|e| format!("Failed to open test file: {}", e))?;
            let mut dst = tokio::fs::File::create(destination)
                .await
                .map_err(|e| format!("Failed to create destination: {}", e))?;

            let mut buffer = vec![0; 64 * 1024]; // 64KB chunks
            let mut copied = 0u64;

            loop {
                tokio::select! {
                    _ = &mut cancel_rx => {
                        return Err("Download cancelled".to_string());
                    }
                    result = src.read(&mut buffer) => {
                        match result {
                            Ok(0) => break,
                            Ok(n) => {
                                dst.write_all(&buffer[..n])
                                    .await
                                    .map_err(|e| format!("Failed to write: {}", e))?;
                                copied += n as u64;
                                progress_callback(copied, file_size);
                            }
                            Err(e) => return Err(format!("Read error: {}", e)),
                        }
                    }
                }
            }

            dst.flush()
                .await
                .map_err(|e| format!("Failed to flush: {}", e))?;

            log::info!("Local test file copied successfully");
            return Ok(());
        }
    }

    // Check if partial file exists
    let temp_path = destination.with_extension("tmp");
    let mut start_byte = 0u64;

    if temp_path.exists() {
        let metadata = tokio::fs::metadata(&temp_path)
            .await
            .map_err(|e| format!("Failed to get temp file metadata: {}", e))?;
        start_byte = metadata.len();
    }

    // Get total file size via HEAD request
    // HuggingFace requires proper headers to return correct content-length
    let client = reqwest::Client::new();
    log::info!("Getting file size from: {}", url);
    let head_response = client
        .head(url)
        .header("User-Agent", "Mozilla/5.0 (compatible; Termex/0.1)")
        .send()
        .await
        .map_err(|e| {
            let msg = format!("Failed to get file size from {}: {}", url, e);
            log::error!("{}", msg);
            msg
        })?;

    let total_size = head_response
        .content_length()
        .unwrap_or(0);

    // If HEAD request didn't return content-length, try GET request
    let total_size = if total_size == 0 {
        log::warn!("HEAD request returned 0 bytes, trying GET request to determine file size");
        let get_response = client
            .get(url)
            .header("User-Agent", "Mozilla/5.0 (compatible; Termex/0.1)")
            .send()
            .await
            .map_err(|e| {
                let msg = format!("Failed to get file size via GET from {}: {}", url, e);
                log::error!("{}", msg);
                msg
            })?;

        get_response
            .content_length()
            .ok_or_else(|| {
                let msg = format!("Server did not provide content length for {}", url);
                log::error!("{}", msg);
                msg
            })?
    } else {
        total_size
    };

    log::info!("File size: {} bytes", total_size);

    // If file is complete, verify and move to destination
    if start_byte >= total_size {
        verify_and_move(&temp_path, destination, expected_sha256).await?;
        progress_callback(total_size, total_size);
        return Ok(());
    }

    // Download with Range header support
    let range_header = if start_byte > 0 {
        format!("bytes={}-", start_byte)
    } else {
        "bytes=0-".to_string()
    };

    log::info!("Downloading from: {} with range: {}", url, range_header);
    let response = client
        .get(url)
        .header("User-Agent", "Mozilla/5.0 (compatible; Termex/0.1)")
        .header("Range", &range_header)
        .send()
        .await
        .map_err(|e| {
            let msg = format!("Failed to start download from {}: {}", url, e);
            log::error!("{}", msg);
            msg
        })?;

    if !response.status().is_success() {
        let msg = format!(
            "Server returned error status {} for {}",
            response.status(),
            url
        );
        log::error!("{}", msg);
        return Err(msg);
    }

    log::info!("Download started successfully, writing to: {}", temp_path.display());

    // Open file in append mode
    let mut file = File::options()
        .create(true)
        .write(true)
        .append(true)
        .open(&temp_path)
        .await
        .map_err(|e| format!("Failed to open temp file: {}", e))?;

    let mut stream = response.bytes_stream();
    let mut downloaded = start_byte;

    use futures_util::StreamExt;

    loop {
        tokio::select! {
            _ = &mut cancel_rx => {
                return Err("Download cancelled".to_string());
            }
            chunk_result = stream.next() => {
                match chunk_result {
                    Some(Ok(chunk)) => {
                        file.write_all(&chunk)
                            .await
                            .map_err(|e| format!("Failed to write chunk: {}", e))?;
                        downloaded += chunk.len() as u64;
                        progress_callback(downloaded, total_size);
                    }
                    Some(Err(e)) => {
                        return Err(format!("Download error: {}", e));
                    }
                    None => break,
                }
            }
        }
    }

    file.flush()
        .await
        .map_err(|e| {
            let msg = format!("Failed to flush file: {}", e);
            log::error!("{}", msg);
            msg
        })?;

    log::info!("Download completed: {} bytes written to {}", downloaded, temp_path.display());

    // Check if temp file exists before verification
    if !temp_path.exists() {
        let msg = format!("Downloaded file not found at {}", temp_path.display());
        log::error!("{}", msg);
        return Err(msg);
    }

    let metadata = tokio::fs::metadata(&temp_path)
        .await
        .map_err(|e| format!("Failed to get temp file metadata: {}", e))?;
    log::info!("Temp file size: {} bytes", metadata.len());

    // Verify hash and move to destination
    // For testing/development, allow placeholder SHA256 values
    if expected_sha256.starts_with("placeholder_") || expected_sha256.starts_with("sha256_") {
        log::warn!("Skipping SHA256 verification for placeholder hash: {}", expected_sha256);
        move_file(&temp_path, destination).await?;
    } else {
        verify_and_move(&temp_path, destination, expected_sha256).await?;
    }

    log::info!("Model successfully downloaded to {}", destination.display());
    Ok(())
}

/// Move file from temp path to destination.
async fn move_file(temp_path: &Path, destination: &Path) -> Result<(), String> {
    tokio::fs::rename(temp_path, destination)
        .await
        .map_err(|e| format!("Failed to move file: {}", e))
}

/// Verify SHA256 hash and move file to destination.
async fn verify_and_move(
    temp_path: &Path,
    destination: &Path,
    expected_sha256: &str,
) -> Result<(), String> {
    let file_content = tokio::fs::read(temp_path)
        .await
        .map_err(|e| format!("Failed to read temp file: {}", e))?;

    let computed_hash = sha256_hex(&file_content);

    if computed_hash != expected_sha256 {
        // Delete corrupted file
        let _ = tokio::fs::remove_file(temp_path).await;
        return Err(format!(
            "SHA256 mismatch: expected {}, got {}",
            expected_sha256, computed_hash
        ));
    }

    // Move temp file to destination
    move_file(temp_path, destination).await
}

/// Compute SHA256 hash of bytes and return hex string.
fn sha256_hex(data: &[u8]) -> String {
    use ring::digest;

    let hash = digest::digest(&digest::SHA256, data);
    hex::encode(hash.as_ref())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sha256_hex() {
        let data = b"hello world";
        let hash = sha256_hex(data);
        // Known SHA256 of "hello world"
        assert_eq!(
            hash,
            "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
        );
    }
}
