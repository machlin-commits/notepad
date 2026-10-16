import AppKit
import SwiftUI

struct PlainTextEditor: NSViewRepresentable {
    @ObservedObject var document: DocumentModel
    let selectionRequest: NSRange?
    let onSelectionHandled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !document.wordWrap
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = document.font.withSize(document.font.pointSize * document.zoom)
        textView.textColor = document.textColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = document.text
        configureWrapping(textView)
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        context.coordinator.document = document
        if textView.string != document.text {
            let selection = textView.selectedRange()
            textView.string = document.text
            textView.setSelectedRange(NSRange(location: min(selection.location, textView.string.utf16.count), length: 0))
        }
        textView.font = document.font.withSize(document.font.pointSize * document.zoom)
        textView.textColor = document.textColor
        scrollView.hasHorizontalScroller = !document.wordWrap
        configureWrapping(textView)
        if let selectionRequest {
            let location = min(selectionRequest.location, textView.string.utf16.count)
            let safe = NSRange(location: location,
                               length: min(selectionRequest.length,
                                           max(0, textView.string.utf16.count - location)))
            textView.setSelectedRange(safe)
            textView.scrollRangeToVisible(safe)
            textView.window?.makeFirstResponder(textView)
            DispatchQueue.main.async { onSelectionHandled() }
        }
    }

    private func configureWrapping(_ textView: NSTextView) {
        guard let container = textView.textContainer else { return }
        if document.wordWrap {
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        } else {
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                             height: CGFloat.greatestFiniteMagnitude)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: DocumentModel
        weak var textView: NSTextView?

        init(document: DocumentModel) {
            self.document = document
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            document.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            document.selectedRange = textView.selectedRange()
        }
    }
}
