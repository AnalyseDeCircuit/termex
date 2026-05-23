import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Modern macOS appearance — fully merge the titlebar into the content
    // view so our Flutter top bar (tabs + traffic-light spacer + right-side
    // icons) renders edge-to-edge under the traffic lights, matching the
    // production Tauri/Vue look.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    // Hide the empty toolbar bar that AppKit otherwise reserves above the
    // content view. Without this a faint horizontal line appears between
    // the traffic-light region and the Flutter content.
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unifiedCompact
    }

    // Lets the user drag the window by clicking any non-interactive area
    // (Flutter's GestureDetectors / buttons still capture their hits
    // first; bare ColoredBoxes / Containers fall through to AppKit which
    // treats them as titlebar drag regions).
    self.isMovableByWindowBackground = true

    // Enforce a sensible minimum window size for a terminal app.
    self.minSize = NSSize(width: 900, height: 600)

    // Persist & restore window frame across launches via AppKit's built-in
    // mechanism. AppKit stores the frame in NSUserDefaults under
    // "NSWindow Frame {autosaveName}" and restores it before
    // contentViewController is attached.
    self.setFrameAutosaveName("TermexMainWindow")

    // First-launch fallback: if AppKit had nothing to restore, the XIB's
    // 800x600 default is too small. Center a sensible default size.
    if self.frame.width < 900 {
      let screen = self.screen ?? NSScreen.main
      let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
      let newWidth: CGFloat = min(1200, screenFrame.width * 0.85)
      let newHeight: CGFloat = min(750, screenFrame.height * 0.85)
      let newX = screenFrame.origin.x + (screenFrame.width - newWidth) / 2
      let newY = screenFrame.origin.y + (screenFrame.height - newHeight) / 2
      self.setFrame(NSRect(x: newX, y: newY, width: newWidth, height: newHeight),
                    display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
