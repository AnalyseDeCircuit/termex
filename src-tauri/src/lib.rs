// Modules moved to termex-core; re-exported here so existing commands/ imports are unchanged.
pub use termex_core::ai;
pub use termex_core::audit;
pub use termex_core::cloud;
pub use termex_core::crypto;
pub use termex_core::keychain;
pub mod monitor;
pub use termex_core::paths;
pub use termex_core::plugin;
pub use termex_core::recording;
pub use termex_core::storage;
pub use termex_core::team;

// Tauri-coupled modules remain in this crate.
pub mod commands;
pub mod local_ai;
pub mod local_pty;
pub mod sftp;
pub mod ssh;
mod state;

use tauri::menu::{CheckMenuItem, CheckMenuItemBuilder, Menu, MenuBuilder, MenuItemBuilder, SubmenuBuilder};
use tauri::{Emitter, Manager, Wry};

use state::AppState;

/// Return type for build_menu: the menu itself plus CheckMenuItem refs for state sync.
struct AppMenu {
    menu: Menu<Wry>,
    toggle_sidebar: CheckMenuItem<Wry>,
    toggle_ai: CheckMenuItem<Wry>,
}

/// Builds the native application menu, returning CheckMenuItem refs for state sync.
fn build_menu(app: &tauri::App) -> Result<AppMenu, Box<dyn std::error::Error>> {
    // App submenu (macOS "Termex" menu)
    let settings = MenuItemBuilder::with_id("settings", "Settings...")
        .accelerator("CmdOrCtrl+,")
        .build(app)?;

    let app_menu = SubmenuBuilder::new(app, "Termex")
        .about(None)
        .separator()
        .item(&settings)
        .separator()
        .services()
        .separator()
        .hide()
        .hide_others()
        .show_all()
        .separator()
        .quit()
        .build()?;

    // File submenu
    let new_connection = MenuItemBuilder::with_id("new_connection", "New Connection")
        .accelerator("CmdOrCtrl+N")
        .build(app)?;
    let new_group = MenuItemBuilder::with_id("new_group", "New Group")
        .build(app)?;
    // Custom "Close Tab" instead of .close_window() which kills the entire window.
    let close_tab = MenuItemBuilder::with_id("close_tab", "Close Tab")
        .accelerator("CmdOrCtrl+W")
        .build(app)?;

    let file_menu = SubmenuBuilder::new(app, "File")
        .item(&new_connection)
        .item(&new_group)
        .separator()
        .item(&close_tab)
        .build()?;

    // Edit submenu
    let edit_menu = SubmenuBuilder::new(app, "Edit")
        .undo()
        .redo()
        .separator()
        .cut()
        .copy()
        .paste()
        .select_all()
        .build()?;

    // View submenu — CheckMenuItem for toggle state sync with frontend.
    // We clone these items so on_menu_event can access them directly
    // (Menu::get() does not search recursively into submenus).
    let toggle_sidebar = CheckMenuItemBuilder::with_id("toggle_sidebar", "Sidebar")
        .accelerator("CmdOrCtrl+\\")
        .checked(true)
        .build(app)?;
    let toggle_ai = CheckMenuItemBuilder::with_id("toggle_ai", "AI Panel")
        .accelerator("CmdOrCtrl+Shift+I")
        .checked(false)
        .build(app)?;

    let view_menu = SubmenuBuilder::new(app, "View")
        .item(&toggle_sidebar)
        .item(&toggle_ai)
        .build()?;

    // Window submenu
    let window_menu = SubmenuBuilder::new(app, "Window")
        .minimize()
        .maximize()
        .separator()
        .fullscreen()
        .build()?;

    // Help submenu
    let check_update = MenuItemBuilder::with_id("check_update", "Check for Updates...")
        .build(app)?;
    let privacy_policy = MenuItemBuilder::with_id("privacy_policy", "Privacy Policy")
        .build(app)?;

    let help_menu = SubmenuBuilder::new(app, "Help")
        .item(&check_update)
        .separator()
        .item(&privacy_policy)
        .build()?;

    let menu = MenuBuilder::new(app)
        .item(&app_menu)
        .item(&file_menu)
        .item(&edit_menu)
        .item(&view_menu)
        .item(&window_menu)
        .item(&help_menu)
        .build()?;

    Ok(AppMenu { menu, toggle_sidebar, toggle_ai })
}

/// Auto-starts the local AI engine if a model was previously used.
async fn auto_start_local_ai(handle: tauri::AppHandle) {
    let state = match handle.try_state::<AppState>() {
        Some(s) => s,
        None => return,
    };

    // Check if auto-start is enabled (default: true)
    let auto_start = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT value FROM settings WHERE key = 'local_ai_auto_start'",
                [],
                |row| row.get::<_, String>(0),
            )
        })
        .unwrap_or_else(|_| "true".to_string());

    if auto_start != "true" {
        return;
    }

    // Get last used model
    let last_model = match state.db.with_conn(|conn| {
        conn.query_row(
            "SELECT value FROM settings WHERE key = 'local_ai_last_model'",
            [],
            |row| row.get::<_, String>(0),
        )
    }) {
        Ok(m) => m,
        Err(_) => return, // No last model — skip
    };

    // Check model file exists
    let model_path = paths::models_dir().join(format!("{last_model}.gguf"));
    if !model_path.exists() {
        log::info!("[local-ai] last model file not found: {}", model_path.display());
        return;
    }

    // Check if another instance already running (PID file or port probe)
    if let Some((pid, port)) = local_ai::read_pid_file() {
        if local_ai::is_pid_alive(pid) {
            log::info!("[local-ai] reusing existing instance (PID={pid}, port={port})");
            let mut server = state.llama_server.write().await;
            server.process_id = Some(pid);
            server.port = Some(port);
            server.loaded_model = Some(model_path.to_string_lossy().to_string());
            server.is_owner = false;
            let _ = handle.emit("local-ai://status", serde_json::json!({
                "running": true, "model": last_model, "reused": true,
            }));
            return;
        }
    }

    // Notify frontend: auto-starting in 3 seconds
    let _ = handle.emit("local-ai://auto-start", serde_json::json!({
        "model": last_model, "delayMs": 3000,
    }));

    tokio::time::sleep(std::time::Duration::from_secs(3)).await;

    // Check if user cancelled
    if state
        .local_ai_auto_start_cancelled
        .load(std::sync::atomic::Ordering::Relaxed)
    {
        log::info!("[local-ai] auto-start cancelled by user");
        return;
    }

    // Find llama-server binary
    let default_bin = paths::bin_dir().join("llama-server");
    let binary_path = match local_ai::binary_manager::ensure_binary_exists(&default_bin).await {
        Ok(p) => std::path::PathBuf::from(p),
        Err(_) => {
            log::info!("[local-ai] llama-server binary not found, skipping auto-start");
            return;
        }
    };

    // Start engine
    let mut server = state.llama_server.write().await;
    match server
        .start(binary_path, model_path)
        .await
    {
        Ok(port) => {
            log::info!("[local-ai] auto-started model '{last_model}' on port {port}");
            drop(server);
            let _ = handle.emit("local-ai://status", serde_json::json!({
                "running": true, "model": last_model, "reused": false,
            }));
            // Start health check to auto-restart if llama-server crashes
            local_ai::health_check::start_health_check_from_handle(handle.clone(), 10, 3);
        }
        Err(e) => {
            log::warn!("[local-ai] auto-start failed: {e}");
            let _ = handle.emit("local-ai://auto-start-failed", serde_json::json!({
                "model": last_model, "error": e,
            }));
        }
    }
}

/// Initializes and runs the Tauri application.
pub fn run() {
    // Initialize logging with env_logger
    // This reads the RUST_LOG environment variable (e.g., RUST_LOG=info, RUST_LOG=debug)
    env_logger::Builder::from_default_env()
        .format_timestamp_millis()
        .init();

    // Install ring as the default rustls CryptoProvider (required for TLS proxy connections)
    let _ = tokio_rustls::rustls::crypto::ring::default_provider().install_default();

    // Clean up any leftover llama-server processes from previous app runs
    // This ensures we start with a clean state
    eprintln!(">>> [INIT] Cleaning up any leftover llama-server processes...");
    #[cfg(not(target_os = "windows"))]
    {
        let _ = std::process::Command::new("pkill")
            .arg("-f")
            .arg("llama-server")
            .output();
    }
    #[cfg(target_os = "windows")]
    {
        let _ = std::process::Command::new("taskkill")
            .arg("/F")
            .arg("/IM")
            .arg("llama-server.exe")
            .output();
    }

    // Initialize path resolver (detects portable mode via .portable marker file)
    paths::init();

    // MVP: no master password — database is unencrypted.
    // When user sets a master password, it encrypts credential fields via AES-256-GCM.
    let app_state = AppState::new(None).expect("failed to initialize database");

    tauri::Builder::default()
        .manage(app_state)
        .manage(local_pty::PtyRegistry::new())
        .manage(commands::cloud::LogRegistry::new())
        .setup(|app| {
            let app_handle = app.handle();
            let state = app.state::<AppState>();

            // Check keychain verification and detect system password changes
            match state.check_keychain_verification() {
                Ok(true) => {
                    // Keychain verified - update app version for upgrade detection
                    state.update_app_version(env!("CARGO_PKG_VERSION"));
                }
                Ok(false) => {
                    // Keychain not available (e.g., headless Linux) - normal, continue
                    state.update_app_version(env!("CARGO_PKG_VERSION"));
                }
                Err(e) => {
                    // Keychain verification failed - likely system password changed
                    // Emit event to frontend to show verification dialog
                    let _ = app_handle.emit("keychain://verification_required", format!("Keychain access failed: {}", e));
                }
            }

            // Clean up old audit logs (90 day retention)
            crate::audit::cleanup(&state.db, 90);

            // Clean up expired recordings (default 90 day retention)
            {
                let retention_days: i64 = state.db.with_conn(|conn| {
                    conn.query_row(
                        "SELECT value FROM settings WHERE key = 'recordingRetentionDays'",
                        [],
                        |row| row.get::<_, String>(0),
                    )
                }).ok()
                    .and_then(|v| v.parse().ok())
                    .unwrap_or(90);

                if retention_days > 0 {
                    let paths = state.db.with_conn(|conn| {
                        crate::storage::recording::cleanup_expired(conn, retention_days)
                    }).unwrap_or_default();
                    for path in &paths {
                        let _ = std::fs::remove_file(path);
                    }
                    if !paths.is_empty() {
                        log::info!("Cleaned up {} expired recordings", paths.len());
                    }
                }
            }

            // On Windows/Linux: remove native decorations — the custom HTML titlebar
            // in TerminalTabs.vue provides window controls (min/max/close) and drag.
            // On macOS: keep decorations + Overlay mode (traffic lights handled natively).
            #[cfg(not(target_os = "macos"))]
            {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.set_decorations(false);
                }
            }

            // Auto-start local AI engine (if previously used)
            {
                let handle = app.handle().clone();
                tauri::async_runtime::spawn(async move {
                    auto_start_local_ai(handle).await;
                });
            }

            let app_menu = build_menu(app)?;
            app.set_menu(app_menu.menu)?;

            // Register CheckMenuItem refs for frontend sync (Menu::get doesn't search submenus)
            let toggle_sidebar_ref = app_menu.toggle_sidebar;
            let toggle_ai_ref = app_menu.toggle_ai;
            let mut check_items = std::collections::HashMap::new();
            check_items.insert("toggle_sidebar".to_string(), toggle_sidebar_ref.clone());
            check_items.insert("toggle_ai".to_string(), toggle_ai_ref.clone());
            app.manage(commands::menu::MenuCheckItems(std::sync::Mutex::new(check_items)));

            app.on_menu_event(move |app_handle, event| {
                match event.id().as_ref() {
                    "settings" => {
                        let _ = app_handle.emit("menu://settings", ());
                    }
                    "new_connection" => {
                        let _ = app_handle.emit("menu://new-connection", ());
                    }
                    "new_group" => {
                        let _ = app_handle.emit("menu://new-group", ());
                    }
                    "close_tab" => {
                        let _ = app_handle.emit("menu://close-tab", ());
                    }
                    "toggle_sidebar" => {
                        // CheckMenuItem auto-toggles on click/accelerator.
                        // Read the new checked state so the frontend can SET (not toggle).
                        let checked = toggle_sidebar_ref.is_checked().unwrap_or(true);
                        let _ = app_handle.emit("menu://toggle-sidebar", checked);
                    }
                    "toggle_ai" => {
                        let checked = toggle_ai_ref.is_checked().unwrap_or(false);
                        let _ = app_handle.emit("menu://toggle-ai", checked);
                    }
                    "check_update" => {
                        let _ = app_handle.emit("menu://check-update", ());
                    }
                    "privacy_policy" => {
                        let _ = app_handle.emit("menu://privacy-policy", ());
                    }
                    _ => {}
                }
            });

            Ok(())
        })
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::Destroyed = event {
                let handle = window.app_handle().clone();
                std::thread::spawn(move || {
                    let rt = tokio::runtime::Runtime::new().unwrap();
                    rt.block_on(async {
                        // Stop all port forwards and monitors
                        if let Some(state) = handle.try_state::<AppState>() {
                            // Stop all monitor collectors
                            let mut collectors = state.monitor_collectors.write().await;
                            for (_, collector) in collectors.drain() {
                                let _ = collector.cmd_tx.send(monitor::CollectorCommand::Stop);
                            }
                            drop(collectors);

                            let mut fwd = state.forwards.write().await;
                            for (_, active) in fwd.drain() {
                                active.stop();
                            }
                            drop(fwd);

                            // Stop all active recordings before disconnecting
                            {
                                let session_ids: Vec<String> = state.sessions.read().await.keys().cloned().collect();
                                for sid in &session_ids {
                                    if state.recorder.is_recording(sid).await {
                                        let _ = state.recorder.stop(sid).await;
                                    }
                                }
                            }

                            // Disconnect all SSH sessions
                            let mut sessions = state.sessions.write().await;
                            for (_, session) in sessions.drain() {
                                let _ = session.disconnect().await;
                            }
                            drop(sessions);

                            // Close all proxy sessions
                            let mut proxies = state.proxy_sessions.write().await;
                            for (_, entry) in proxies.drain() {
                                let _ = entry.session.disconnect().await;
                            }
                            drop(proxies);
                        }

                        // Close all local PTY sessions
                        if let Some(pty_reg) = handle.try_state::<local_pty::PtyRegistry>() {
                            pty_reg.close_all();
                        }

                        // Close all cloud log streams
                        if let Some(log_reg) = handle.try_state::<commands::cloud::LogRegistry>() {
                            log_reg.close_all();
                        }
                    });
                });
            }
        })
        .invoke_handler(tauri::generate_handler![
            // Master password
            commands::crypto::master_password_exists,
            commands::crypto::master_password_set,
            commands::crypto::master_password_verify,
            commands::crypto::master_password_change,
            commands::crypto::master_password_lock,
            commands::crypto::keychain_verify,
            commands::crypto::check_password_strength,
            // Server & group management
            commands::server::server_list,
            commands::server::server_create,
            commands::server::server_update,
            commands::server::server_delete,
            commands::server::server_get_credentials,
            commands::server::server_touch,
            commands::server::server_set_shared,
            commands::server::server_reorder,
            commands::server::group_list,
            commands::server::group_create,
            commands::server::group_update,
            commands::server::group_delete,
            commands::server::group_reorder,
            // Proxy
            commands::proxy::proxy_list,
            commands::proxy::proxy_create,
            commands::proxy::proxy_update,
            commands::proxy::proxy_delete,
            commands::proxy::proxy_get_password,
            commands::proxy::proxy_set_shared,
            commands::proxy::proxy_make_local,
            // SSH
            commands::ssh::ssh_connect,
            commands::ssh::ssh_open_shell,
            commands::ssh::ssh_test,
            commands::ssh::ssh_disconnect,
            commands::ssh::ssh_write,
            commands::ssh::ssh_resize,
            commands::ssh::ssh_exec,
            commands::ssh::ssh_host_key_respond,
            commands::ssh::ssh_known_hosts_list,
            commands::ssh::ssh_known_hosts_remove,
            // Port Forwarding
            commands::port_forward::port_forward_list,
            commands::port_forward::port_forward_save,
            commands::port_forward::port_forward_delete,
            commands::port_forward::port_forward_start,
            commands::port_forward::port_forward_stop,
            // Settings
            commands::settings::settings_get,
            commands::settings::settings_get_all,
            commands::settings::settings_set,
            commands::settings::settings_delete,
            // Config Export/Import
            commands::config::config_export,
            commands::config::config_import,
            // AI
            commands::ai::ai_provider_list,
            commands::ai::ai_provider_add,
            commands::ai::ai_provider_update,
            commands::ai::ai_provider_delete,
            commands::ai::ai_provider_set_default,
            commands::ai::ai_check_danger,
            commands::ai::ai_explain_command,
            commands::ai::ai_nl2cmd,
            commands::ai::ai_provider_get_key,
            commands::ai::ai_provider_test,
            commands::ai::ai_provider_test_direct,
            commands::ai::ai_autocomplete,
            commands::ai::ai_chat,
            commands::ai::ai_diagnose,
            commands::ai::ai_orchestrate,
            commands::ai::ai_validate_step,
            commands::ai::ai_session_summary,
            // Local AI
            commands::local_ai::local_ai_engine_status,
            commands::local_ai::local_ai_start_engine,
            commands::local_ai::local_ai_stop_engine,
            commands::local_ai::local_ai_list_downloaded,
            commands::local_ai::local_ai_download_model,
            commands::local_ai::local_ai_delete_model,
            commands::local_ai::local_ai_cancel_download,
            commands::local_ai::local_ai_start_health_check,
            commands::local_ai::local_ai_cancel_auto_start,
            commands::local_ai::local_ai_check_disk_space,
            // Recording
            commands::recording::recording_start,
            commands::recording::recording_stop,
            commands::recording::recording_is_active,
            commands::recording::recording_list,
            commands::recording::recording_read,
            commands::recording::recording_delete,
            commands::recording::recording_cleanup,
            commands::recording::recording_export_text,
            commands::recording::recording_summarize,
            commands::recording::recording_get_dir,
            commands::recording::recording_open_dir,
            commands::recording::recording_set_shared,
            commands::recording::recording_make_local,
            // Team
            commands::team::team_create,
            commands::team::team_join,
            commands::team::team_sync,
            commands::team::team_leave,
            commands::team::team_get_status,
            commands::team::team_list_members,
            commands::team::team_set_role,
            commands::team::team_remove_member,
            commands::team::team_verify_passphrase,
            commands::team::team_toggle_share,
            commands::team::team_rotate_key,
            commands::team_ext::team_check_permission,
            commands::team_ext::team_list_roles,
            commands::team_ext::team_my_capabilities,
            commands::team::team_resolve_conflicts,
            commands::team_ext::team_generate_invite_token,
            commands::team_ext::team_decode_invite,
            commands::team_ext::team_get_credentials,
            commands::team_ext::team_role_create,
            commands::team_ext::team_role_update,
            commands::team_ext::team_role_delete,
            // Plugins
            commands::plugin::plugin_list,
            commands::plugin::plugin_install,
            commands::plugin::plugin_uninstall,
            commands::plugin::plugin_enable,
            commands::plugin::plugin_disable,
            // SFTP
            commands::sftp::sftp_open,
            commands::sftp::sftp_close,
            commands::sftp::sftp_list_dir,
            commands::sftp::sftp_mkdir,
            commands::sftp::sftp_delete,
            commands::sftp::sftp_rename,
            commands::sftp::sftp_read_file,
            commands::sftp::sftp_write_file,
            commands::sftp::sftp_download,
            commands::sftp::sftp_upload,
            commands::sftp::sftp_canonicalize,
            commands::sftp::sftp_transfer,
            // Local filesystem
            commands::local_fs::local_home_dir,
            commands::local_fs::local_list_dir,
            commands::local_fs::local_rename,
            commands::local_fs::local_delete,
            commands::local_fs::local_mkdir,
            commands::local_fs::local_create_file,
            commands::local_fs::security_status,
            commands::local_fs::open_url,
            commands::local_fs::save_file_dialog,
            commands::local_fs::open_file_dialog,
            commands::local_fs::open_local_terminal,
            // Local PTY
            local_pty::local_pty_open,
            local_pty::local_pty_write,
            local_pty::local_pty_resize,
            local_pty::local_pty_close,
            // Fonts
            commands::fonts::fonts_list_custom,
            commands::fonts::fonts_upload,
            commands::fonts::fonts_delete,
            commands::fonts::fonts_read,
            // Update
            commands::update::get_platform_info,
            commands::update::download_update,
            commands::update::exit_app,
            // Menu
            commands::menu::set_menu_checked,
            // Tor
            commands::tor::tor_detect,
            // Portable
            commands::portable::is_portable,
            // Git Sync
            commands::git_sync::git_sync_deploy,
            commands::git_sync::git_sync_setup_tunnel,
            commands::git_sync::git_sync_pull,
            // Clipboard
            commands::clipboard::clipboard_read_text,
            // Audit
            commands::audit::audit_log_list,
            commands::audit::audit_log_summary,
            commands::audit::audit_export_report,
            commands::audit::audit_log_cleanup,
            // Privacy (GDPR)
            commands::privacy::privacy_erase_all_data,
            commands::privacy::privacy_data_summary,
            // Snippets
            commands::snippet::snippet_list,
            commands::snippet::snippet_create,
            commands::snippet::snippet_update,
            commands::snippet::snippet_delete,
            commands::snippet::snippet_set_shared,
            commands::snippet::snippet_make_local,
            commands::snippet::snippet_execute,
            commands::snippet::snippet_extract_variables,
            commands::snippet::snippet_folder_list,
            commands::snippet::snippet_folder_create,
            commands::snippet::snippet_folder_update,
            commands::snippet::snippet_folder_delete,
            // SSH Config Import
            commands::ssh_config::ssh_config_preview,
            commands::ssh_config::ssh_config_import,
            commands::ssh_config::ssh_config_import_termius,
            commands::ssh_config::ssh_config_import_csv,
            // Monitor
            commands::monitor::monitor_start,
            commands::monitor::monitor_stop,
            commands::monitor::monitor_get_latest,
            commands::monitor::monitor_get_history,
            // Cloud
            commands::cloud::cloud_detect_tools,
            commands::cloud::cloud_kube_available,
            commands::cloud::cloud_ssm_available,
            commands::cloud::cloud_kube_list_contexts,
            commands::cloud::cloud_kube_list_namespaces,
            commands::cloud::cloud_kube_list_pods,
            commands::cloud::cloud_kube_exec,
            commands::cloud::cloud_ssm_list_profiles,
            commands::cloud::cloud_ssm_list_instances,
            commands::cloud::cloud_ssm_connect,
            commands::cloud::cloud_kube_logs,
            commands::cloud::cloud_kube_logs_stop,
            commands::cloud::cloud_favorite_list,
            commands::cloud::cloud_favorite_create,
            commands::cloud::cloud_favorite_delete,
            commands::cloud::cloud_favorite_set_shared,
            commands::cloud::cloud_favorite_make_local,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Termex");
}
