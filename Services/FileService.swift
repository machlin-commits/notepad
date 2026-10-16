import AppKit
import Foundation
import UniformTypeIdentifiers

enum FileService {
    static func openPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .sourceCode]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func savePanel(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName == "Untitled" ? "Untitled.txt" : suggestedName
        panel.allowedContentTypes = [.plainText]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func read(from url: URL) throws -> DecodedText {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try EncodingService.decode(Data(contentsOf: url))
    }

    static func write(_ document: DocumentModel, to url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
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
