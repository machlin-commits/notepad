import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var documents: [DocumentModel] = []
    @Published var selectedDocumentID: UUID?
    @Published var isFindPresented = false
    @Published var isReplacePresented = false
    @Published var findText = ""
    @Published var replaceText = ""
    @Published var caseSensitive = false
    @Published var wholeWord = false
    @Published var matchIndex = 0
    @Published var matchCount = 0
    @Published var editorSelectionRequest: NSRange?
    @Published var errorMessage: String?

    private var cancellables: Set<AnyCancellable> = []
    private var watchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var watchedDescriptors: [UUID: Int32] = [:]

    var selectedDocument: DocumentModel? {
        documents.first { $0.id == selectedDocumentID }
    }

    init() {
        restoreSession()
        if documents.isEmpty { newTab() }
    }

    deinit {
        watchers.values.forEach { $0.cancel() }
        watchedDescriptors.values.forEach { close($0) }
    }

    func newTab() {
        let document = DocumentModel()
        documents.append(document)
        selectedDocumentID = document.id
        observe(document)
        persistSession()
    }

    func open() {
        guard let url = FileService.openPanel() else { return }
        open(url)
    }

    func open(_ url: URL) {
        do {
            let decoded = try FileService.read(from: url)
            let document = DocumentModel(text: decoded.text, fileURL: url,
                                         displayName: url.lastPathComponent,
                                         encoding: decoded.encoding,
                                         lineEnding: decoded.lineEnding)
            document.attributedText = try FileService.readRichText(from: url) ?? NSAttributedString(string: decoded.text)
            document.bookmarkData = FileService.bookmark(for: url)
            documents.append(document)
            selectedDocumentID = document.id
            observe(document)
            watch(document)
            persistSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() {
        guard let document = selectedDocument else { return }
        if let url = document.fileURL, !document.containsImages || url.pathExtension.lowercased() == "rtfd" {
            save(document, to: url)
        } else {
            saveAs()
        }
    }

    func saveAs() {
        guard let document = selectedDocument,
              let url = FileService.savePanel(suggestedName: document.suggestedFileName, richText: document.usesRTFD) else { return }
        save(document, to: url)
    }

    private func save(_ document: DocumentModel, to url: URL) {
        do {
            watchers[document.id]?.cancel()
            if let descriptor = watchedDescriptors.removeValue(forKey: document.id) { close(descriptor) }
            watchers.removeValue(forKey: document.id)
            try FileService.write(document, to: url)
            document.fileURL = url
            document.displayName = url.lastPathComponent
            document.bookmarkData = FileService.bookmark(for: url)
            document.isDirty = false
            document.externalChangeDetected = false
            RecoveryService.shared.remove(id: document.id)
            watch(document)
            persistSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeTab(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let document = documents[index]
        if document.isDirty {
            let alert = NSAlert()
            alert.messageText = "Save changes to “\(document.displayName)”?"
            alert.informativeText = "Your changes will be lost if you don’t save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Don’t Save")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                selectedDocumentID = id
                save()
                if document.isDirty { return }
            } else if response == .alertSecondButtonReturn {
                return
            }
        }
        watchers[id]?.cancel()
        if let descriptor = watchedDescriptors.removeValue(forKey: id) { close(descriptor) }
        watchers.removeValue(forKey: id)
        RecoveryService.shared.remove(id: id)
        documents.remove(at: index)
        selectedDocumentID = documents.indices.contains(index) ? documents[index].id : documents.last?.id
        if documents.isEmpty { newTab() }
        persistSession()
    }

    func showFind(replace: Bool = false) {
        isFindPresented = true
        isReplacePresented = replace
        updateMatches()
    }

    func findNext(backwards: Bool = false) {
        let matches = ranges()
        matchCount = matches.count
        guard !matches.isEmpty else { matchIndex = 0; return }
        if backwards {
            matchIndex = matchIndex <= 1 ? matches.count : matchIndex - 1
        } else {
            matchIndex = matchIndex >= matches.count ? 1 : matchIndex + 1
        }
        let range = matches[matchIndex - 1]
        selectedDocument?.selectedRange = range
        editorSelectionRequest = range
    }

    func replaceCurrent() {
        guard let document = selectedDocument, matchCount > 0 else { return }
        let range = document.selectedRange
        guard range.location + range.length <= (document.text as NSString).length else { return }
        document.replaceCharacters(in: range, with: replaceText)
        document.isDirty = true
        updateMatches()
        findNext()
    }

    func replaceAll() {
        guard let document = selectedDocument, !findText.isEmpty else { return }
        let ranges = ranges().reversed()
        let updated = NSMutableAttributedString(attributedString: document.attributedText)
        for range in ranges { updated.replaceCharacters(in: range, with: replaceText) }
        document.attributedText = updated
        document.isDirty = true
        updateMatches()
    }

    func updateMatches() {
        matchCount = ranges().count
        matchIndex = matchCount == 0 ? 0 : min(max(matchIndex, 1), matchCount)
    }

    func goToLine() {
        guard let document = selectedDocument else { return }
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter a line number:"
        let field = NSTextField(string: "")
        field.placeholderString = "Line"
        alert.accessoryView = field
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn,
              let line = Int(field.stringValue), line > 0 else { return }
        let lines = document.text.components(separatedBy: "\n")
        let clamped = min(line, max(lines.count, 1))
        let location = lines.prefix(clamped - 1).reduce(0) { $0 + $1.utf16.count + 1 }
        let range = NSRange(location: location, length: 0)
        document.selectedRange = range
        editorSelectionRequest = range
    }

    func insertDateTime() {
        guard let document = selectedDocument else { return }
        let value = Date().formatted(date: .numeric, time: .shortened)
        let range = document.selectedRange
        document.replaceCharacters(in: range, with: value)
        let caret = NSRange(location: range.location + value.utf16.count, length: 0)
        document.selectedRange = caret
        editorSelectionRequest = caret
        document.isDirty = true
    }

    func chooseFont() {
        guard let document = selectedDocument else { return }
        NSFontManager.shared.setSelectedFont(document.font, isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(nil)
    }

    func printDocument() {
        if let document = selectedDocument { PrintService.printDocument(document) }
    }

    func reloadExternalChange() {
        guard let document = selectedDocument, let url = document.fileURL else { return }
        do {
            let decoded = try FileService.read(from: url)
            document.attributedText = try FileService.readRichText(from: url) ?? NSAttributedString(string: decoded.text)
            document.encoding = decoded.encoding
            document.lineEnding = decoded.lineEnding
            document.isDirty = false
            document.externalChangeDetected = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func keepMine() {
        selectedDocument?.externalChangeDetected = false
    }

    private func ranges() -> [NSRange] {
        guard let document = selectedDocument, !findText.isEmpty else { return [] }
        let source = document.text as NSString
        let options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: source.length)
        while searchRange.length > 0 {
            let found = source.range(of: findText, options: options, range: searchRange)
            guard found.location != NSNotFound else { break }
            let isWhole = !wholeWord || isWholeWord(found, in: document.text)
            if isWhole { result.append(found) }
            let next = found.location + max(found.length, 1)
            searchRange = NSRange(location: next, length: source.length - next)
        }
        return result
    }

    private func isWholeWord(_ range: NSRange, in text: String) -> Bool {
        let ns = text as NSString
        let set = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        func isWord(_ location: Int) -> Bool {
            guard location >= 0, location < ns.length,
                  let scalar = UnicodeScalar(ns.character(at: location)) else { return false }
            return set.contains(scalar)
        }
        return !isWord(range.location - 1) && !isWord(range.location + range.length)
    }

    private func observe(_ document: DocumentModel) {
        document.$attributedText.dropFirst().sink { [weak self, weak document] content in
            guard let self, let document else { return }
            document.isDirty = true
            // Published values arrive before the stored property changes.
            let snapshot = DocumentSnapshot(id: document.id, text: content.string, fileURL: document.fileURL,
                                        displayName: document.displayName, encoding: document.encoding,
                                        lineEnding: document.lineEnding, date: Date(),
                                        richTextData: content.rtfd(from: NSRange(location: 0, length: content.length),
                                                                   documentAttributes: [:]))
            RecoveryService.shared.schedule(snapshot)
            if self.selectedDocumentID == document.id { self.updateMatches() }
        }.store(in: &cancellables)
    }

    private func watch(_ document: DocumentModel) {
        guard let url = document.fileURL else { return }
        let descriptor = Darwin.open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak document] in
            DispatchQueue.main.async { document?.externalChangeDetected = true }
        }
        source.resume()
        watchers[document.id] = source
        watchedDescriptors[document.id] = descriptor
    }

    private func persistSession() {
        SessionService.save(documents)
    }

    private func restoreSession() {
        let recovered = Dictionary(uniqueKeysWithValues:
            RecoveryService.shared.recoveredSnapshots().map { ($0.id, $0) })
        for tab in SessionService.restore() {
            if let snapshot = recovered[tab.id] {
                let document = DocumentModel(id: snapshot.id, text: snapshot.text,
                                             fileURL: snapshot.fileURL,
                                             displayName: snapshot.displayName,
                                             encoding: snapshot.encoding,
                                             lineEnding: snapshot.lineEnding,
                                             isDirty: true)
                if let data = snapshot.richTextData,
                   let content = NSAttributedString(rtfd: data, documentAttributes: nil) {
                    document.attributedText = content
                }
                documents.append(document)
                observe(document)
                if document.fileURL != nil { watch(document) }
            } else if let url = tab.fileURL, let decoded = try? FileService.read(from: url) {
                let document = DocumentModel(id: tab.id, text: decoded.text, fileURL: url,
                                             displayName: tab.displayName,
                                             encoding: decoded.encoding,
                                             lineEnding: decoded.lineEnding)
                if let richText = try? FileService.readRichText(from: url) {
                    document.attributedText = richText
                }
                document.bookmarkData = tab.bookmarkData
                documents.append(document)
                observe(document)
                watch(document)
            }
        }
        selectedDocumentID = documents.first?.id
    }
}
