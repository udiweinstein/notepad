import AppKit

/// One open file = one Document = one tab.
@objc(Document)
final class Document: NSDocument {

    /// Set briefly by "New Window" so the next document opens in its own window instead of a tab.
    static var nextOpensInNewWindow = false

    let textStorage = NSTextStorage()
    var encoding: TextEncoding = .utf8
    var lineEnding: LineEnding = .defaultForNewDocuments

    /// Called whenever the whole text is replaced (open, revert, reopen with encoding).
    var onContentReplaced: (() -> Void)?

    override init() {
        super.init()
        hasUndoManager = true
    }

    // Behave like Notepad: explicit Save, and a "save changes?" prompt on close.
    override class var autosavesInPlace: Bool { false }
    override class func isNativeType(_ type: String) -> Bool { true }
    override class var writableTypes: [String] { ["public.plain-text"] }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        var types = ["public.plain-text"]
        if let current = fileType, current != "public.plain-text" { types.insert(current, at: 0) }
        return types
    }

    override var shouldRunSavePanelWithAccessoryView: Bool { false }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.canSelectHiddenExtension = true
        return true
    }

    // MARK: Window

    override func makeWindowControllers() {
        let controller = EditorWindowController(document: self)
        if Document.nextOpensInNewWindow, let window = controller.window {
            window.tabbingMode = .disallowed
            DispatchQueue.main.async { window.tabbingMode = .preferred }
        }
        addWindowController(controller)
    }

    // MARK: Reading & writing

    override func read(from data: Data, ofType typeName: String) throws {
        let (text, detected) = TextEncoding.detect(data)
        setContent(text, encoding: detected)
    }

    override func data(ofType typeName: String) throws -> Data {
        for case let controller as EditorWindowController in windowControllers {
            controller.textView.breakUndoCoalescing()
        }
        let text = lineEnding.apply(to: textStorage.string)
        guard let data = encoding.encode(text) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteInapplicableStringEncodingError, userInfo: [
                NSLocalizedDescriptionKey: "This text contains characters that can’t be saved as \(encoding.name).",
                NSLocalizedRecoverySuggestionErrorKey: "Choose UTF-8 from the encoding menu in the status bar and save again.",
            ])
        }
        return data
    }

    func setContent(_ raw: String, encoding newEncoding: TextEncoding) {
        encoding = newEncoding
        lineEnding = LineEnding.detect(in: raw) ?? .defaultForNewDocuments
        let text = LineEnding.normalize(raw)

        let undo = undoManager
        undo?.disableUndoRegistration()
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
        textStorage.endEditing()
        undo?.enableUndoRegistration()
        undo?.removeAllActions()

        onContentReplaced?()
    }

    /// File ▸ Reopen with Encoding — re-reads the file on disk with an explicit encoding.
    func reopen(with newEncoding: TextEncoding) throws {
        guard let url = fileURL else {
            encoding = newEncoding
            onContentReplaced?()
            return
        }
        let data = try Data(contentsOf: url)
        guard let text = newEncoding.decode(data) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadInapplicableStringEncodingError, userInfo: [
                NSLocalizedDescriptionKey: "“\(url.lastPathComponent)” can’t be read as \(newEncoding.name).",
            ])
        }
        setContent(text, encoding: newEncoding)
        updateChangeCount(.changeCleared)
    }

    // MARK: Printing

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let info = (printInfo.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
        for (key, value) in printSettings { info.dictionary()[key.rawValue] = value }
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false

        let width = max(100, info.paperSize.width - info.leftMargin - info.rightMargin)
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.textStorage?.setAttributedString(NSAttributedString(string: textStorage.string, attributes: [
            .font: Settings.font,
            .foregroundColor: NSColor.black,
        ]))
        view.sizeToFit()

        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.jobTitle = displayName
        return operation
    }
}
