import AppKit
import Combine
import Foundation

enum TextEncoding: String, Codable, CaseIterable, Identifiable {
    case utf8 = "UTF-8"
    case utf8BOM = "UTF-8 with BOM"
    case utf16LittleEndian = "UTF-16 LE"
    case utf16BigEndian = "UTF-16 BE"
    case utf32LittleEndian = "UTF-32 LE"
    case utf32BigEndian = "UTF-32 BE"
    case ascii = "ASCII"
    case macRoman = "Mac Roman"
    case windows1252 = "Windows-1252"

    var id: String { rawValue }

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: .utf8
        case .utf16LittleEndian: .utf16LittleEndian
        case .utf16BigEndian: .utf16BigEndian
        case .utf32LittleEndian: .utf32LittleEndian
        case .utf32BigEndian: .utf32BigEndian
        case .ascii: .ascii
        case .macRoman: .macOSRoman
        case .windows1252: .windowsCP1252
        }
    }

    var byteOrderMark: Data {
        switch self {
        case .utf8BOM: Data([0xEF, 0xBB, 0xBF])
        case .utf16LittleEndian: Data([0xFF, 0xFE])
        case .utf16BigEndian: Data([0xFE, 0xFF])
        case .utf32LittleEndian: Data([0xFF, 0xFE, 0x00, 0x00])
        case .utf32BigEndian: Data([0x00, 0x00, 0xFE, 0xFF])
        default: Data()
        }
    }
}

enum LineEnding: String, Codable, CaseIterable, Identifiable {
    case lf = "Unix (LF)"
    case crlf = "Windows (CRLF)"
    case cr = "Classic Mac (CR)"

    var id: String { rawValue }
    var sequence: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        case .cr: "\r"
        }
    }
}

struct DocumentSnapshot: Codable {
    let id: UUID
    let text: String
    let fileURL: URL?
    let displayName: String
    let encoding: TextEncoding
    let lineEnding: LineEnding
    let date: Date
    var richTextData: Data? = nil
}

@MainActor
final class DocumentModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var attributedText: NSAttributedString
    var text: String { attributedText.string }

    func replaceCharacters(in range: NSRange, with value: String) {
        let updated = NSMutableAttributedString(attributedString: attributedText)
        updated.replaceCharacters(in: range, with: value)
        attributedText = updated
    }

    var containsImages: Bool {
        var found = false
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    var usesRTFD: Bool {
        containsImages || fileURL?.pathExtension.lowercased() == "rtfd"
    }
    @Published var fileURL: URL?
    @Published var displayName: String
    @Published var encoding: TextEncoding
    @Published var lineEnding: LineEnding
    @Published var isDirty: Bool
    @Published var selectedRange = NSRange(location: 0, length: 0)
    @Published var zoom: Double = 1
    @Published var wordWrap = true
    @Published var font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    @Published var textColor: NSColor = .textColor
    @Published var externalChangeDetected = false
    var bookmarkData: Data?

    init(
        id: UUID = UUID(),
        text: String = "",
        fileURL: URL? = nil,
        displayName: String = "Untitled",
        encoding: TextEncoding = .utf8,
        lineEnding: LineEnding = .lf,
        isDirty: Bool = false
    ) {
        self.id = id
        self.attributedText = NSAttributedString(string: text)
        self.fileURL = fileURL
        self.displayName = displayName
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
    }

    var tabTitle: String {
        if let fileURL { return fileURL.lastPathComponent }
        let firstLine = text.replacingOccurrences(of: "\u{FFFC}", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        guard !firstLine.isEmpty else { return "Untitled" }
        return String(firstLine.prefix(40))
    }

    var suggestedFileName: String {
        if let fileURL { return fileURL.lastPathComponent }
        let name = tabTitle.components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
        return name + (usesRTFD ? ".rtfd" : ".txt")
    }

    var lineAndColumn: (Int, Int) {
        let nsText = text as NSString
        let location = min(selectedRange.location, nsText.length)
        let prefix = nsText.substring(to: location)
        let lines = prefix.components(separatedBy: .newlines)
        return (max(lines.count, 1), (lines.last?.utf16.count ?? 0) + 1)
    }

    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isPunctuation }.count
    }

    var snapshot: DocumentSnapshot {
        DocumentSnapshot(id: id, text: text, fileURL: fileURL, displayName: displayName,
                         encoding: encoding, lineEnding: lineEnding, date: Date(),
                         richTextData: containsImages ? attributedText.rtfd(from: NSRange(location: 0, length: attributedText.length), documentAttributes: [:]) : nil)
    }
}
