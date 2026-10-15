import AppKit

/// Windows-Notepad style status bar:
/// Ln 1, Col 1 | 0 characters            100% | Unix (LF) | UTF-8
final class StatusBarView: NSView {

    let positionLabel = StatusBarView.makeLabel()
    let countLabel = StatusBarView.makeLabel()
    let zoomLabel = StatusBarView.makeLabel()
    private let lineEndingPopup = StatusBarView.makePopup()
    private let encodingPopup = StatusBarView.makePopup()

    var onLineEndingChange: ((LineEnding) -> Void)?
    var onEncodingChange: ((TextEncoding) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        for ending in LineEnding.allCases {
            lineEndingPopup.addItem(withTitle: ending.title)
            lineEndingPopup.lastItem?.tag = ending.rawValue
        }
        for (index, encoding) in TextEncoding.all.enumerated() {
            encodingPopup.addItem(withTitle: encoding.name)
            encodingPopup.lastItem?.tag = index
        }
        lineEndingPopup.target = self
        lineEndingPopup.action = #selector(lineEndingChanged(_:))
        lineEndingPopup.toolTip = "Line endings used when saving"
        encodingPopup.target = self
        encodingPopup.action = #selector(encodingChanged(_:))
        encodingPopup.toolTip = "Encoding used when saving (File ▸ Reopen with Encoding re-reads the file)"

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        positionLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [
            positionLabel, Self.divider(), countLabel, spacer,
            zoomLabel, Self.divider(), lineEndingPopup, Self.divider(), encodingPopup,
        ])
        stack.orientation = .horizontal
        stack.distribution = .fill
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(lineEnding: LineEnding, encoding: TextEncoding) {
        lineEndingPopup.selectItem(withTag: lineEnding.rawValue)
        if let index = TextEncoding.all.firstIndex(of: encoding) {
            encodingPopup.selectItem(withTag: index)
        }
    }

    @objc private func lineEndingChanged(_ sender: NSPopUpButton) {
        if let ending = LineEnding(rawValue: sender.selectedTag()) { onLineEndingChange?(ending) }
    }

    @objc private func encodingChanged(_ sender: NSPopUpButton) {
        let index = sender.selectedTag()
        if index >= 0, index < TextEncoding.all.count { onEncodingChange?(TextEncoding.all[index]) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }

    // MARK: Factories

    private static func makeLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }

    private static func makePopup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.isBordered = false
        popup.controlSize = .small
        popup.font = .systemFont(ofSize: 11)
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return popup
    }

    private static func divider() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 1),
            box.heightAnchor.constraint(equalToConstant: 12),
        ])
        return box
    }
}
