import AppKit
import Foundation
import UniformTypeIdentifiers

enum FileService {
    static func openPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .sourceCode, .rtfd]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func savePanel(suggestedName: String, richText: Bool) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = richText
            ? (suggestedName as NSString).deletingPathExtension + ".rtfd"
            : (suggestedName == "Untitled" ? "Untitled.txt" : suggestedName)
        panel.allowedContentTypes = richText ? [.rtfd] : [.plainText]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func read(from url: URL) throws -> DecodedText {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let richText = try readRichText(from: url) {
            return DecodedText(text: richText.string, encoding: .utf8, lineEnding: .lf)
        }
        return try EncodingService.decode(Data(contentsOf: url))
    }

    static func readRichText(from url: URL) throws -> NSAttributedString? {
        guard url.pathExtension.lowercased() == "rtfd" else { return nil }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                      documentAttributes: nil)
    }

    static func write(_ document: DocumentModel, to url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if document.usesRTFD {
            let wrapper = try document.attributedText.fileWrapper(
                from: NSRange(location: 0, length: document.attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
            return
        }
        let data = try EncodingService.encode(document.text, encoding: document.encoding,
                                              lineEnding: document.lineEnding)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        try data.write(to: url, options: .atomic)
        if let permissions = attributes?[.posixPermissions] {
            try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
        }
    }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                              relativeTo: nil)
    }
}
