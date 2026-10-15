import Foundation

// MARK: - Text encoding (what Windows Notepad shows in the status bar: "UTF-8", "UTF-16 LE", "ANSI"...)

struct TextEncoding: Equatable {
    let name: String
    let encoding: String.Encoding
    let hasBOM: Bool

    static let utf8 = TextEncoding(name: "UTF-8", encoding: .utf8, hasBOM: false)
    static let utf8BOM = TextEncoding(name: "UTF-8 with BOM", encoding: .utf8, hasBOM: true)
    static let utf16LE = TextEncoding(name: "UTF-16 LE", encoding: .utf16LittleEndian, hasBOM: true)
    static let utf16BE = TextEncoding(name: "UTF-16 BE", encoding: .utf16BigEndian, hasBOM: true)
    static let windowsHebrew = TextEncoding(name: "Windows-1255 (Hebrew)", encoding: TextEncoding.cf(.windowsHebrew), hasBOM: false)
    static let isoHebrew = TextEncoding(name: "ISO-8859-8 (Hebrew)", encoding: TextEncoding.cf(.isoLatinHebrew), hasBOM: false)
    static let windowsArabic = TextEncoding(name: "Windows-1256 (Arabic)", encoding: TextEncoding.cf(.windowsArabic), hasBOM: false)
    static let windowsWestern = TextEncoding(name: "Windows-1252 (Western)", encoding: .windowsCP1252, hasBOM: false)

    /// Order shown in the status-bar popup and in File ▸ Reopen with Encoding.
    static let all: [TextEncoding] = [.utf8, .utf8BOM, .utf16LE, .utf16BE,
                                      .windowsHebrew, .isoHebrew, .windowsArabic, .windowsWestern]

    private static func cf(_ e: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(e.rawValue)))
    }

    private static let utf8Mark: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let utf16LEMark: [UInt8] = [0xFF, 0xFE]
    private static let utf16BEMark: [UInt8] = [0xFE, 0xFF]

    private var bomBytes: [UInt8] {
        guard hasBOM else { return [] }
        if encoding == .utf8 { return TextEncoding.utf8Mark }
        if encoding == .utf16LittleEndian { return TextEncoding.utf16LEMark }
        if encoding == .utf16BigEndian { return TextEncoding.utf16BEMark }
        return []
    }

    /// Decode data with this specific encoding (a leading BOM of the same family is skipped).
    func decode(_ data: Data) -> String? {
        var body = data
        if encoding == .utf8, data.starts(with: TextEncoding.utf8Mark) {
            body = data.dropFirst(3)
        } else if encoding == .utf16LittleEndian, data.starts(with: TextEncoding.utf16LEMark) {
            body = data.dropFirst(2)
        } else if encoding == .utf16BigEndian, data.starts(with: TextEncoding.utf16BEMark) {
            body = data.dropFirst(2)
        }
        return String(data: body, encoding: encoding)
    }

    func encode(_ text: String) -> Data? {
        guard let body = text.data(using: encoding, allowLossyConversion: false) else { return nil }
        var data = Data(bomBytes)
        data.append(body)
        return data
    }

    /// Detect the encoding of a file the way Notepad does: BOM first, then UTF-8, then a legacy code page.
    static func detect(_ data: Data) -> (String, TextEncoding) {
        if data.starts(with: utf8Mark), let s = utf8BOM.decode(data) { return (s, .utf8BOM) }
        if data.starts(with: utf16LEMark), let s = utf16LE.decode(data) { return (s, .utf16LE) }
        if data.starts(with: utf16BEMark), let s = utf16BE.decode(data) { return (s, .utf16BE) }
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }

        // Not valid UTF-8: guess between Hebrew and Western code pages.
        // In Windows-1255 the Hebrew letters live in 0xE0–0xFA.
        var high = 0, hebrewRange = 0
        for byte in data where byte >= 0x80 {
            high += 1
            if byte >= 0xE0 && byte <= 0xFA { hebrewRange += 1 }
        }
        let candidates: [TextEncoding] = (high > 0 && hebrewRange * 2 >= high)
            ? [.windowsHebrew, .windowsWestern]
            : [.windowsWestern, .windowsHebrew]
        for candidate in candidates {
            if let s = candidate.decode(data) { return (s, candidate) }
        }
        return (String(decoding: data, as: UTF8.self), .utf8)
    }
}

// MARK: - Line endings

enum LineEnding: Int, CaseIterable {
    case crlf, lf, cr

    static let defaultForNewDocuments: LineEnding = .lf

    var title: String {
        switch self {
        case .crlf: return "Windows (CRLF)"
        case .lf: return "Unix (LF)"
        case .cr: return "Macintosh (CR)"
        }
    }

    var sequence: String {
        switch self {
        case .crlf: return "\r\n"
        case .lf: return "\n"
        case .cr: return "\r"
        }
    }

    /// The style of the first line break in the text, or nil if there is none.
    static func detect(in text: String) -> LineEnding? {
        let ns = text as NSString
        let r = ns.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n"))
        guard r.location != NSNotFound else { return nil }
        if ns.character(at: r.location) == 0x0A { return .lf }
        if r.location + 1 < ns.length, ns.character(at: r.location + 1) == 0x0A { return .crlf }
        return .cr
    }

    /// The editor always works with "\n" internally.
    static func normalize(_ text: String) -> String {
        let m = NSMutableString(string: text)
        m.replaceOccurrences(of: "\r\n", with: "\n", options: .literal, range: NSRange(location: 0, length: m.length))
        m.replaceOccurrences(of: "\r", with: "\n", options: .literal, range: NSRange(location: 0, length: m.length))
        return m as String
    }

    /// Converts editor text to this line-ending style for saving.
    func apply(to text: String) -> String {
        let m = NSMutableString(string: LineEnding.normalize(text))
        if self != .lf {
            m.replaceOccurrences(of: "\n", with: sequence, options: .literal, range: NSRange(location: 0, length: m.length))
        }
        return m as String
    }
}
