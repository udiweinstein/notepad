import AppKit

/// App-wide preferences shared by every tab (like Notepad's Format/View menus).
enum Settings {
    static let didChange = Notification.Name("NotepadSettingsDidChange")
    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: ["WordWrap": true, "ShowStatusBar": true, "WindowsKeys": true])
    }

    static var defaultFont: NSFont {
        NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    static var font: NSFont {
        get {
            let size = defaults.double(forKey: "FontSize")
            if let name = defaults.string(forKey: "FontName"), size > 0,
               let font = NSFont(name: name, size: CGFloat(size)) {
                return font
            }
            return defaultFont
        }
        set {
            defaults.set(newValue.fontName, forKey: "FontName")
            defaults.set(Double(newValue.pointSize), forKey: "FontSize")
            notify()
        }
    }

    static var wordWrap: Bool {
        get { defaults.bool(forKey: "WordWrap") }
        set { defaults.set(newValue, forKey: "WordWrap"); notify() }
    }

    static var showStatusBar: Bool {
        get { defaults.bool(forKey: "ShowStatusBar") }
        set { defaults.set(newValue, forKey: "ShowStatusBar"); notify() }
    }

    /// Windows navigation keys (Home/End, Ctrl+Home/End, Ctrl+←/→, Page Up/Down …).
    static var windowsKeys: Bool {
        get { defaults.bool(forKey: "WindowsKeys") }
        set { defaults.set(newValue, forKey: "WindowsKeys"); notify() }
    }

    static func resetFont() {
        defaults.removeObject(forKey: "FontName")
        defaults.removeObject(forKey: "FontSize")
        notify()
    }

    private static func notify() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    func applicationWillFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        _ = NSDocumentController.shared          // must exist before files are opened
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApp.mainMenu = MainMenu.build(appDelegate: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: File

    /// ⌘N / ⌘T — new tab in the current window (Windows 11 Notepad behaviour).
    @objc func newTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    /// The "+" button in the tab bar.
    @objc func newWindowForTab(_ sender: Any?) {
        newTab(sender)
    }

    /// ⇧⌘N — new separate window.
    @objc func newWindow(_ sender: Any?) {
        Document.nextOpensInNewWindow = true
        defer { Document.nextOpensInNewWindow = false }
        NSDocumentController.shared.newDocument(sender)
    }

    @objc func saveAllDocuments(_ sender: Any?) {
        for document in NSDocumentController.shared.documents where document.isDocumentEdited {
            document.save(sender)
        }
    }

    // MARK: Format / View

    @objc func toggleWordWrap(_ sender: Any?) { Settings.wordWrap.toggle() }
    @objc func toggleStatusBar(_ sender: Any?) { Settings.showStatusBar.toggle() }
    @objc func resetFont(_ sender: Any?) { Settings.resetFont() }
    @objc func toggleWindowsKeys(_ sender: Any?) { Settings.windowsKeys.toggle() }

    @objc func showFontPanel(_ sender: Any?) {
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeFontFromPanel(_:))
        manager.setSelectedFont(Settings.font, isMultiple: false)
        manager.orderFrontFontPanel(self)
    }

    @objc func changeFontFromPanel(_ sender: Any?) {
        guard let manager = sender as? NSFontManager else { return }
        Settings.font = manager.convert(Settings.font)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleWordWrap(_:)):
            menuItem.state = Settings.wordWrap ? .on : .off
        case #selector(toggleWindowsKeys(_:)):
            menuItem.state = Settings.windowsKeys ? .on : .off
        case #selector(toggleStatusBar(_:)):
            menuItem.state = Settings.showStatusBar ? .on : .off
        case #selector(saveAllDocuments(_:)):
            return NSDocumentController.shared.documents.contains { $0.isDocumentEdited }
        default:
            break
        }
        return true
    }
}
