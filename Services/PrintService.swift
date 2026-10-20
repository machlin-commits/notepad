import AppKit

enum PrintService {
    @MainActor
    static func printDocument(_ document: DocumentModel) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        textView.isRichText = true
        textView.font = document.font
        textView.textStorage?.setAttributedString(document.attributedText)
        textView.textContainerInset = NSSize(width: 36, height: 36)
        let operation = NSPrintOperation(view: textView)
        operation.printInfo.horizontalPagination = .fit
        operation.printInfo.verticalPagination = .automatic
        operation.run()
    }
}
