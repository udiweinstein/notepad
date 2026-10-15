import AppKit

/// The menu bar, built in code. Windows Notepad's menus mapped to Mac conventions.
enum MainMenu {

    static func build(appDelegate app: AppDelegate) -> NSMenu {
        let main = NSMenu(title: "Main Menu")
        let name = "Notepad"
        let docs = NSDocumentController.shared

        // MARK: Notepad
        let appMenu = submenu(in: main, title: name)
        add(appMenu, "About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        appMenu.addItem(.separator())
        let services = NSMenu(title: "Services")
        add(appMenu, "Services", nil).submenu = services
        NSApp.servicesMenu = services
        appMenu.addItem(.separator())
        add(appMenu, "Hide \(name)", #selector(NSApplication.hide(_:)), "h")
        add(appMenu, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        add(appMenu, "Show All", #selector(NSApplication.unhideAllApplications(_:)), "")
        appMenu.addItem(.separator())
        add(appMenu, "Quit \(name)", #selector(NSApplication.terminate(_:)), "q")

        // MARK: File
        let file = submenu(in: main, title: "File")
        add(file, "New Tab", #selector(AppDelegate.newTab(_:)), "n", target: app)
        hidden(add(file, "New Tab", #selector(AppDelegate.newTab(_:)), "t", target: app))
        add(file, "New Window", #selector(AppDelegate.newWindow(_:)), "n", [.command, .shift], target: app)
        add(file, "Open…", sel("openDocument:"), "o", target: docs)

        let recent = NSMenu(title: "Open Recent")
        _ = recent.perform(NSSelectorFromString("_setMenuName:"), with: "NSRecentDocumentsMenu")
        add(recent, "Clear Menu", sel("clearRecentDocuments:"), "", target: docs)
        add(file, "Open Recent", nil).submenu = recent

        let reopen = NSMenu(title: "Reopen with Encoding")
        for (index, encoding) in TextEncoding.all.enumerated() {
            add(reopen, encoding.name, #selector(EditorWindowController.reopenWithEncoding(_:)), "", tag: index)
        }
        add(file, "Reopen with Encoding", nil).submenu = reopen

        file.addItem(.separator())
        add(file, "Save", sel("saveDocument:"), "s")
        add(file, "Save As…", sel("saveDocumentAs:"), "s", [.command, .shift])
        add(file, "Save All", #selector(AppDelegate.saveAllDocuments(_:)), "s", [.command, .option], target: app)
        add(file, "Revert to Saved", sel("revertDocumentToSaved:"), "")
        file.addItem(.separator())
        add(file, "Page Setup…", sel("runPageLayout:"), "p", [.command, .shift])
        add(file, "Print…", sel("printDocument:"), "p")
        file.addItem(.separator())
        add(file, "Close Tab", #selector(NSWindow.performClose(_:)), "w")
        add(file, "Close Window", #selector(EditorWindowController.closeWindowGroup(_:)), "w", [.command, .shift])

        // MARK: Edit
        let edit = submenu(in: main, title: "Edit")
        add(edit, "Undo", sel("undo:"), "z")
        add(edit, "Redo", sel("redo:"), "z", [.command, .shift])
        edit.addItem(.separator())
        add(edit, "Cut", #selector(NSText.cut(_:)), "x")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Delete", #selector(NSText.delete(_:)), "")
        edit.addItem(.separator())
        let find = #selector(NSTextView.performFindPanelAction(_:))
        add(edit, "Find…", find, "f", tag: NSTextFinder.Action.showFindInterface.rawValue)
        add(edit, "Find Next", find, "g", tag: NSTextFinder.Action.nextMatch.rawValue)
        add(edit, "Find Previous", find, "g", [.command, .shift], tag: NSTextFinder.Action.previousMatch.rawValue)
        add(edit, "Replace…", find, "f", [.command, .option], tag: NSTextFinder.Action.showReplaceInterface.rawValue)
        add(edit, "Use Selection for Find", find, "e", tag: NSTextFinder.Action.setSearchString.rawValue)
        add(edit, "Go To Line…", #selector(EditorWindowController.goToLine(_:)), "l")
        edit.addItem(.separator())
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())
        add(edit, "Windows Navigation Keys", #selector(AppDelegate.toggleWindowsKeys(_:)), "", target: app)
        add(edit, "Time/Date", #selector(EditorWindowController.insertTimeDate(_:)), functionKey(NSF5FunctionKey), [])

        // MARK: Format
        let format = submenu(in: main, title: "Format")
        add(format, "Word Wrap", #selector(AppDelegate.toggleWordWrap(_:)), "", target: app)
        add(format, "Font…", #selector(AppDelegate.showFontPanel(_:)), "t", [.command, .control], target: app)
        add(format, "Reset Font", #selector(AppDelegate.resetFont(_:)), "", target: app)
        format.addItem(.separator())
        add(format, "Right-to-Left Reading Order", #selector(EditorWindowController.toggleRightToLeft(_:)), "r", [.command, .control])

        // MARK: View
        let view = submenu(in: main, title: "View")
        let zoom = NSMenu(title: "Zoom")
        add(zoom, "Zoom In", #selector(EditorWindowController.zoomIn(_:)), "+")
        hidden(add(zoom, "Zoom In", #selector(EditorWindowController.zoomIn(_:)), "="))
        add(zoom, "Zoom Out", #selector(EditorWindowController.zoomOut(_:)), "-")
        add(zoom, "Restore Default Zoom", #selector(EditorWindowController.resetZoom(_:)), "0")
        add(view, "Zoom", nil).submenu = zoom
        add(view, "Status Bar", #selector(AppDelegate.toggleStatusBar(_:)), "", target: app)
        view.addItem(.separator())
        add(view, "Show Tab Bar", sel("toggleTabBar:"), "")
        add(view, "Show All Tabs", sel("toggleTabOverview:"), "\\", [.command, .shift])
        view.addItem(.separator())
        add(view, "Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])

        // MARK: Window
        let window = submenu(in: main, title: "Window")
        add(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(window, "Zoom", #selector(NSWindow.performZoom(_:)), "")
        window.addItem(.separator())
        add(window, "Show Previous Tab", sel("selectPreviousTab:"), functionKey(NSLeftArrowFunctionKey), [.command, .option])
        add(window, "Show Next Tab", sel("selectNextTab:"), functionKey(NSRightArrowFunctionKey), [.command, .option])
        hidden(add(window, "Show Next Tab", sel("selectNextTab:"), "\t", [.control]))
        hidden(add(window, "Show Previous Tab", sel("selectPreviousTab:"), "\t", [.control, .shift]))
        add(window, "Move Tab to New Window", sel("moveTabToNewWindow:"), "")
        add(window, "Merge All Windows", sel("mergeAllWindows:"), "")
        for number in 1...9 {
            hidden(add(window, "Select Tab \(number)", #selector(EditorWindowController.selectTabByNumber(_:)),
                       String(number), tag: number))
        }
        window.addItem(.separator())
        add(window, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)), "")
        NSApp.windowsMenu = window

        // MARK: Help
        let help = submenu(in: main, title: "Help")
        NSApp.helpMenu = help

        return main
    }

    // MARK: Helpers

    /// Standard AppKit actions that have no Swift-visible declaration.
    private static func sel(_ name: String) -> Selector { NSSelectorFromString(name) }

    private static func submenu(in main: NSMenu, title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
        return menu
    }

    @discardableResult
    private static func add(_ menu: NSMenu, _ title: String, _ action: Selector?, _ key: String = "",
                            _ modifiers: NSEvent.ModifierFlags = [.command],
                            target: AnyObject? = nil, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        item.tag = tag
        menu.addItem(item)
        return item
    }

    /// A shortcut-only alias that doesn't clutter the menu.
    private static func hidden(_ item: NSMenuItem) {
        item.isHidden = true
        item.allowsKeyEquivalentWhenHidden = true
    }

    private static func functionKey(_ code: Int) -> String {
        guard let scalar = UnicodeScalar(UInt32(code)) else { return "" }
        return String(Character(scalar))
    }
}
