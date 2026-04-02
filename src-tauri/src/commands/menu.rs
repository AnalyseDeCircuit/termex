use tauri::{AppHandle, Manager};
use tauri::menu::MenuItemKind;

/// Updates a CheckMenuItem's checked state from the frontend.
/// Used to sync View menu checkmarks with panel visibility.
#[tauri::command]
pub fn set_menu_checked(app: AppHandle, id: String, checked: bool) -> Result<(), String> {
    if let Some(menu) = app.menu() {
        if let Some(MenuItemKind::Check(item)) = menu.get(&id) {
            item.set_checked(checked).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}
