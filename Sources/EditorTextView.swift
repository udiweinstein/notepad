import AppKit

/// NSTextView with Windows-style navigation & selection keys.
///
///   Home / End                     start / end of line            (+Shift = select)
///   Ctrl+Home / Ctrl+End           start / end of document        (+Shift = select)
///   Ctrl+← / Ctrl+→                previous / next word           (+Shift = select)
///   Page Up / Page Down            move the caret a page          (+Shift = select)
///   Ctrl+Backspace / Ctrl+Delete   delete previous / next word
///   Ctrl+A                         select all
///
/// ⌘ works as Ctrl for these keys too, so the same shortcuts work on a Mac keyboard
/// (fn+← = Home, fn+→ = End, fn+↑ = Page Up, fn+↓ = Page Down).
/// The usual Mac shortcuts (⌘←, ⌥←, ⌘↑ …) keep working.
final class EditorTextView: NSTextView {

    /// Set by the window controller when the user forces right-to-left reading order.
    var forceRightToLeft = false

    /// The moving end of the selection (the other end is the anchor), as Windows tracks it.
    private var activeEnd: Int?

    override func keyDown(with event: NSEvent) {
        let before = selectedRange()
        if !(Settings.windowsKeys && handleWindowsKey(event)) {
            super.keyDown(with: event)
        }
        trackActiveEnd(before: before, extending: event.modifierFlags.contains(.shift))
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        activeEnd = nil
    }

    // MARK: - Key mapping

    private func handleWindowsKey(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.unicodeScalars, chars.count == 1,
              let key = chars.first.map({ Int($0.value) }) else { return false }

        let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
        if flags.contains(.option) { return false }          // ⌥ keeps its Mac meaning
        let shift = flags.contains(.shift)
        let ctrl = flags.contains(.control)
        let cmd = flags.contains(.command)
        let ctrlLike = ctrl || cmd

        func run(_ plain: String, _ extend: String) -> Bool {
            doCommand(by: NSSelectorFromString(shift ? extend : plain))
            return true
        }

        switch key {
        case NSHomeFunctionKey:
            return ctrlLike
                ? run("moveToBeginningOfDocument:", "moveToBeginningOfDocumentAndModifySelection:")
                : run("moveToBeginningOfLine:", "moveToBeginningOfLineAndModifySelection:")

        case NSEndFunctionKey:
            return ctrlLike
                ? run("moveToEndOfDocument:", "moveToEndOfDocumentAndModifySelection:")
                : run("moveToEndOfLine:", "moveToEndOfLineAndModifySelection:")

        case NSPageUpFunctionKey where !ctrlLike:
            return run("pageUp:", "pageUpAndModifySelection:")

        case NSPageDownFunctionKey where !ctrlLike:
            return run("pageDown:", "pageDownAndModifySelection:")

        // Ctrl+←/→ only: ⌘←/→ already mean start/end of line on the Mac.
        case NSLeftArrowFunctionKey where ctrl && !cmd:
            moveWord(visualLeft: true, extend: shift)
            return true

        case NSRightArrowFunctionKey where ctrl && !cmd:
            moveWord(visualLeft: false, extend: shift)
            return true

        case 0x7F where ctrl && !cmd && !shift:              // Ctrl+Backspace
            doCommand(by: #selector(deleteWordBackward(_:)))
            return true

        case NSDeleteFunctionKey where ctrl && !cmd && !shift: // Ctrl+Delete (fn+Ctrl+Backspace)
            doCommand(by: #selector(deleteWordForward(_:)))
            return true

        case 0x61 where ctrl && !cmd && !shift,              // Ctrl+A
             0x01 where ctrl && !cmd && !shift:
            selectAll(nil)
            return true

        default:
            return false
        }
    }

    // MARK: - Windows word movement

    /// Windows semantics: Ctrl+→ goes to the START of the next word (skipping the spaces after it),
    /// and punctuation runs count as their own "words". In a right-to-left paragraph the arrows swap.
    private func moveWord(visualLeft: Bool, extend: Bool) {
        let text = string as NSString
        let selection = selectedRange()
        let rtl = isRightToLeftParagraph(at: selection.location, in: text)
        let forward = visualLeft == rtl

        // Where does the move start from?
        let from: Int
        if extend || selection.length == 0 {
            from = currentActiveEnd(selection, forward: forward)
        } else {
            from = forward ? NSMaxRange(selection) : selection.location
        }

        let target = forward ? nextWordStart(from, in: text) : previousWordStart(from, in: text)

        if !extend {
            setSelectedRange(NSRange(location: target, length: 0))
            scrollRangeToVisible(NSRange(location: target, length: 0))
            activeEnd = nil
            return
        }

        // Extend by stepping one character at a time through NSTextView's own commands,
        // so its built-in anchor stays correct when mixed with Shift+Home, Shift+↓ etc.
        let steps = abs(target - from)
        let step = NSSelectorFromString(target > from ? "moveForwardAndModifySelection:" : "moveBackwardAndModifySelection:")
        for _ in 0..<steps { doCommand(by: step) }
        activeEnd = target
    }

    private enum CharClass { case space, newline, word, punct }

    private static func charClass(_ c: unichar) -> CharClass {
        if c == 0x0A || c == 0x0D { return .newline }
        guard let scalar = UnicodeScalar(c) else { return .word }  // surrogate halves: treat as word
        if CharacterSet.whitespaces.contains(scalar) { return .space }
        if c == 0x5F || CharacterSet.alphanumerics.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar) {
            return .word
        }
        // Hebrew geresh/gershayim and apostrophes inside words (e.g. צ'יפס, don't) stay in the word.
        if c == 0x27 || c == 0x2019 || c == 0x05F3 || c == 0x05F4 || c == 0x22 { return .word }
        return .punct
    }

    private func nextWordStart(_ index: Int, in text: NSString) -> Int {
        let length = text.length
        var i = index
        guard i < length else { return length }
        let first = Self.charClass(text.character(at: i))
        if first == .newline { return i + 1 }
        if first != .space {
            while i < length, Self.charClass(text.character(at: i)) == first { i += 1 }
        }
        while i < length, Self.charClass(text.character(at: i)) == .space { i += 1 }
        return i
    }

    private func previousWordStart(_ index: Int, in text: NSString) -> Int {
        var i = index
        guard i > 0 else { return 0 }
        if Self.charClass(text.character(at: i - 1)) == .newline { return i - 1 }
        while i > 0, Self.charClass(text.character(at: i - 1)) == .space { i -= 1 }
        guard i > 0 else { return 0 }
        let cls = Self.charClass(text.character(at: i - 1))
        if cls == .newline { return i }
        while i > 0, Self.charClass(text.character(at: i - 1)) == cls { i -= 1 }
        return i
    }

    /// Paragraph direction = first strong character (like the bidi algorithm), unless RTL is forced.
    private func isRightToLeftParagraph(at index: Int, in text: NSString) -> Bool {
        if forceRightToLeft { return true }
        let paragraph = text.paragraphRange(for: NSRange(location: min(index, text.length), length: 0))
        let end = min(NSMaxRange(paragraph), paragraph.location + 2000)
        var i = paragraph.location
        while i < end {
            let c = text.character(at: i)
            if (0x0590...0x08FF).contains(c) || (0xFB1D...0xFDFF).contains(c) || (0xFE70...0xFEFF).contains(c) {
                return true
            }
            if let scalar = UnicodeScalar(c), CharacterSet.letters.contains(scalar) { return false }
            i += 1
        }
        return false
    }

    // MARK: - Tracking which end of the selection moves

    private func currentActiveEnd(_ selection: NSRange, forward: Bool) -> Int {
        if selection.length == 0 { return selection.location }
        if let active = activeEnd, active == selection.location || active == NSMaxRange(selection) {
            return active
        }
        return forward ? NSMaxRange(selection) : selection.location
    }

    private func trackActiveEnd(before: NSRange, extending: Bool) {
        let after = selectedRange()
        guard extending, after.length > 0 else {
            if after.length == 0 { activeEnd = nil }
            return
        }
        let startKept = after.location == before.location || after.location == NSMaxRange(before)
        let endKept = NSMaxRange(after) == before.location || NSMaxRange(after) == NSMaxRange(before)
        if startKept && !endKept {
            activeEnd = NSMaxRange(after)
        } else if endKept && !startKept {
            activeEnd = after.location
        }
    }
}
