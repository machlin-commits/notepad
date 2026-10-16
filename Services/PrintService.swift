import AppKit

enum PrintService {
    @MainActor
    static func printDocument(_ document: DocumentModel) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        textView.isRichText = false
        textView.font = document.font
        textView.string = document.text
        textView.textContainerInset = NSSize(width: 36, height: 36)
        let operation = NSPrintOperation(view: textView)
        operation.printInfo.horizontalPagination = .fit
        operation.printInfo.verticalPagination = .automatic
        operation.run()
    }
}
