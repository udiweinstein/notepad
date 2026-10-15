import AppKit

/// The window (tab) for one document: text view + Notepad-style status bar.
final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {

    static let tabbingIdentifier = "NotepadEditorWindow"
    private static let minZoom: CGFloat = 0.1
    private static let maxZoom: CGFloat = 5.0

    let textView: EditorTextView
    private let scrollView = NSScrollView()
    private let statusBar = StatusBarView()
    private var statusBarHeight: NSLayoutConstraint!

    private weak var doc: Document?
    private var zoom: CGFloat = 1.0
    private var rightToLeft = false
    private var settingsObserver: NSObjectProtocol?

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    init(document: Document) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 380, height: 240)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = EditorWindowController.tabbingIdentifier

        // TextKit 1 stack sharing the document's text storage.
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        document.textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), textContainer: container)

        doc = document
        super.init(window: window)

        window.delegate = self
        shouldCascadeWindows = true
        configureTextView()
        buildLayout(in: window)
        window.center()

        statusBar.onLineEndingChange = { [weak self] ending in
            guard let self, let doc = self.doc, doc.lineEnding != ending else { return }
            doc.lineEnding = ending
            doc.updateChangeCount(.changeDone)
            self.updateStatus()
        }
        statusBar.onEncodingChange = { [weak self] encoding in
            guard let self, let doc = self.doc, doc.encoding != encoding else { return }
            doc.encoding = encoding
            doc.updateChangeCount(.changeDone)
            self.updateStatus()
        }

        document.onContentReplaced = { [weak self] in
            guard let self else { return }
            self.applyTextAttributes()
            self.textView.setSelectedRange(NSRange(location: 0, length: 0))
            self.textView.scrollToBeginningOfDocument(nil)
            self.updateStatus()
        }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: Settings.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }

        applySettings()
        updateStatus()
        window.initialFirstResponder = textView
        window.makeFirstResponder(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
    }

    // MARK: - Setup

    private func configureTextView() {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = self
    }

    private func buildLayout(in window: NSWindow) {
        guard let content = window.contentView else { return }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        statusBar.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(scrollView)
        content.addSubview(statusBar)
        statusBarHeight = statusBar.heightAnchor.constraint(equalToConstant: 24)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusBarHeight,
        ])

        // Size the text view to the real visible area before installing it,
        // so autoresizing starts from the correct width.
        content.layoutSubtreeIfNeeded()
        textView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
    }

    // MARK: - Settings (font, word wrap, status bar)

    private func applySettings() {
        applyWordWrap(Settings.wordWrap)
        statusBar.isHidden = !Settings.showStatusBar
        statusBarHeight.constant = Settings.showStatusBar ? 24 : 0
        applyTextAttributes()
        updateStatus()
    }

    private func applyWordWrap(_ wrap: Bool) {
        guard let container = textView.textContainer else { return }
        if wrap {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            let width = scrollView.contentSize.width
            textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
            container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width]
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        textView.needsDisplay = true
    }

    private var currentFont: NSFont {
        let base = Settings.font
        let size = min(400, max(4, base.pointSize * zoom))
        return NSFont(descriptor: base.fontDescriptor, size: size) ?? base
    }

    private func paragraphStyle(for font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.baseWritingDirection = rightToLeft ? .rightToLeft : .natural
        style.alignment = .natural
        let charWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        style.tabStops = []
        style.defaultTabInterval = max(1, charWidth * 4)
        return style
    }

    /// Plain-text editor: one font, one color, one paragraph style for everything.
    private func applyTextAttributes() {
        let font = currentFont
        let style = paragraphStyle(for: font)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style,
        ]
        if let storage = textView.textStorage, storage.length > 0 {
            storage.beginEditing()
            storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }
        textView.defaultParagraphStyle = style
        textView.typingAttributes = attributes
    }

    // MARK: - Status bar

    private func updateStatus() {
        guard let storage = textView.textStorage else { return }
        let ns = storage.string as NSString
        let selection = textView.selectedRange()
        let (line, column) = Self.lineAndColumn(in: ns, at: selection.location)
        statusBar.positionLabel.stringValue = "Ln \(format(line)), Col \(format(column))"
        statusBar.countLabel.stringValue = selection.length > 0
            ? "\(format(selection.length)) of \(format(ns.length)) characters"
            : "\(format(ns.length)) characters"
        statusBar.zoomLabel.stringValue = "\(Int((zoom * 100).rounded()))%"
        if let doc {
            statusBar.show(lineEnding: doc.lineEnding, encoding: doc.encoding)
        }
    }

    private func format(_ n: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: n)) ?? String(n)
    }

    private static func lineAndColumn(in ns: NSString, at location: Int) -> (Int, Int) {
        let end = min(location, ns.length)
        var line = 1
        var lineStart = 0
        let chunk = 8192
        var buffer = [unichar](repeating: 0, count: chunk)
        var position = 0
        while position < end {
            let length = min(chunk, end - position)
            ns.getCharacters(&buffer, range: NSRange(location: position, length: length))
            for i in 0..<length where buffer[i] == 0x0A {
                line += 1
                lineStart = position + i + 1
            }
            position += length
        }
        return (line, end - lineStart + 1)
    }

    func textViewDidChangeSelection(_ notification: Notification) { updateStatus() }
    func textDidChange(_ notification: Notification) { updateStatus() }

    // MARK: - Window delegate

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        doc?.undoManager
    }

    // MARK: - Actions (reached through the responder chain)

    @objc func zoomIn(_ sender: Any?) { setZoom(zoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom(zoom - 0.1) }
    @objc func resetZoom(_ sender: Any?) { setZoom(1.0) }

    private func setZoom(_ value: CGFloat) {
        zoom = min(Self.maxZoom, max(Self.minZoom, (value * 10).rounded() / 10))
        applyTextAttributes()
        updateStatus()
    }

    @objc func toggleRightToLeft(_ sender: Any?) {
        rightToLeft.toggle()
        textView.forceRightToLeft = rightToLeft
        applyTextAttributes()
    }

    @objc func insertTimeDate(_ sender: Any?) {
        let now = Date()
        let time = DateFormatter()
        time.dateStyle = .none
        time.timeStyle = .short
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .none
        let stamp = "\(time.string(from: now)) \(date.string(from: now))"
        textView.insertText(stamp, replacementRange: textView.selectedRange())
    }

    @objc func goToLine(_ sender: Any?) {
        guard let window, let storage = textView.textStorage else { return }
        let (currentLine, _) = Self.lineAndColumn(in: storage.string as NSString, at: textView.selectedRange().location)

        let alert = NSAlert()
        alert.messageText = "Go To Line"
        alert.informativeText = "Line number:"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = String(currentLine)
        alert.accessoryView = field
        alert.addButton(withTitle: "Go To")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard let line = Int(text), line >= 1 else { NSSound.beep(); return }
            self.moveCaret(toLine: line)
        }
        alert.window.makeFirstResponder(field)
        field.selectText(nil)
    }

    private func moveCaret(toLine target: Int) {
        guard let storage = textView.textStorage else { return }
        let ns = storage.string as NSString
        var line = 1
        var location = 0
        while line < target {
            let found = ns.range(of: "\n", options: .literal,
                                 range: NSRange(location: location, length: ns.length - location))
            if found.location == NSNotFound {
                let alert = NSAlert()
                alert.messageText = "The line number is beyond the total number of lines."
                if let window { alert.beginSheetModal(for: window, completionHandler: nil) } else { alert.runModal() }
                return
            }
            location = found.location + 1
            line += 1
        }
        let range = NSRange(location: location, length: 0)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        window?.makeFirstResponder(textView)
    }

    @objc func reopenWithEncoding(_ sender: NSMenuItem) {
        guard let doc, sender.tag >= 0, sender.tag < TextEncoding.all.count else { return }
        let encoding = TextEncoding.all[sender.tag]
        let perform = {
            do { try doc.reopen(with: encoding) } catch { _ = doc.presentError(error) }
        }
        if doc.isDocumentEdited, let window = self.window {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Discard unsaved changes?"
            alert.informativeText = "Reopening “\(doc.displayName ?? "")” as \(encoding.name) will discard the changes you made since it was last saved."
            alert.addButton(withTitle: "Reopen")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn { perform() }
            }
        } else {
            perform()
        }
    }

    /// File ▸ Close Window — closes every tab in this window, asking about unsaved ones.
    @objc func closeWindowGroup(_ sender: Any?) {
        guard let window else { return }
        CloseQueue.start(window.tabbedWindows ?? [window])
    }

    /// ⌘1 … ⌘8 select that tab, ⌘9 selects the last tab.
    @objc func selectTabByNumber(_ sender: NSMenuItem) {
        guard let tabs = window?.tabbedWindows, !tabs.isEmpty else { return }
        let index = sender.tag == 9 ? tabs.count - 1 : sender.tag - 1
        guard index >= 0, index < tabs.count else { return }
        tabs[index].makeKeyAndOrderFront(nil)
    }

    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let action = item.action else { return true }
        switch action {
        case #selector(toggleRightToLeft(_:)):
            item.state = rightToLeft ? .on : .off
        case #selector(zoomIn(_:)):
            return zoom < Self.maxZoom - 0.001
        case #selector(zoomOut(_:)):
            return zoom > Self.minZoom + 0.001
        case #selector(resetZoom(_:)):
            return abs(zoom - 1) > 0.001
        case #selector(reopenWithEncoding(_:)):
            let current = doc.flatMap { TextEncoding.all.firstIndex(of: $0.encoding) }
            item.state = (current == item.tag) ? .on : .off
            return doc?.fileURL != nil
        case #selector(selectTabByNumber(_:)):
            return (window?.tabbedWindows?.count ?? 0) > 1
        default:
            break
        }
        return true
    }
}

/// Closes a list of windows one after another, letting each document ask to save.
final class CloseQueue: NSObject {
    private static var active: CloseQueue?
    private var windows: [NSWindow]

    private init(_ windows: [NSWindow]) {
        self.windows = windows
        super.init()
    }

    static func start(_ windows: [NSWindow]) {
        let queue = CloseQueue(windows)
        active = queue
        queue.next()
    }

    private func next() {
        guard !windows.isEmpty else { CloseQueue.active = nil; return }
        let window = windows.removeFirst()
        guard let document = window.windowController?.document as? NSDocument else {
            window.close()
            next()
            return
        }
        window.makeKeyAndOrderFront(nil)
        document.canClose(withDelegate: self,
                          shouldClose: #selector(document(_:shouldClose:contextInfo:)),
                          contextInfo: nil)
    }

    @objc private func document(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if shouldClose {
            document.close()
            next()
        } else {
            windows.removeAll()
            CloseQueue.active = nil
        }
    }
}
