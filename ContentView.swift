import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EditorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TabStripView(viewModel: viewModel)
            Divider()
            PrimaryMenuBarView(viewModel: viewModel)
            Divider()
            if let document = viewModel.selectedDocument {
                FormattingBarView(document: document)
                Divider()
                ZStack(alignment: .top) {
                    PlainTextEditor(
                        document: document,
                        selectionRequest: viewModel.editorSelectionRequest,
                        onSelectionHandled: { viewModel.editorSelectionRequest = nil }
                    )
                    if viewModel.isFindPresented {
                        FindReplaceView(viewModel: viewModel)
                            .padding(.top, 10)
                    }
                }
                Divider()
                StatusBarView(document: document)
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.showFind()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                Button {
                    viewModel.selectedDocument?.wordWrap.toggle()
                } label: {
                    Label("Word Wrap", systemImage: "text.word.spacing")
                }
                Button {
                    viewModel.chooseFont()
                } label: {
                    Label("Font", systemImage: "textformat")
                }
            }
        }
        .modifier(CommandReceiver(viewModel: viewModel))
        .modifier(EditorAlerts(viewModel: viewModel))
    }
}

struct PrimaryMenuBarView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 18) {
            Menu("File") {
                Button("New Tab") { viewModel.newTab() }
                    .keyboardShortcut("t")
                Button("Open…") { viewModel.open() }
                    .keyboardShortcut("o")
                Divider()
                Button("Save") { viewModel.save() }
                    .keyboardShortcut("s")
                Button("Save As…") { viewModel.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("Print…") { viewModel.printDocument() }
                    .keyboardShortcut("p")
            }
            Menu("Edit") {
                Button("Find…") { viewModel.showFind() }
                    .keyboardShortcut("f")
                Button("Find and Replace…") { viewModel.showFind(replace: true) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Go to Line…") { viewModel.goToLine() }
                    .keyboardShortcut("l")
                Divider()
                Button("Insert Date and Time") { viewModel.insertDateTime() }
            }
            Menu("View") {
                Button(viewModel.selectedDocument?.wordWrap == true ? "Disable Word Wrap" : "Enable Word Wrap") {
                    viewModel.selectedDocument?.wordWrap.toggle()
                }
                Divider()
                Button("Zoom In") {
                    guard let document = viewModel.selectedDocument else { return }
                    document.zoom = min(document.zoom + 0.1, 5)
                }
                Button("Zoom Out") {
                    guard let document = viewModel.selectedDocument else { return }
                    document.zoom = max(document.zoom - 0.1, 0.5)
                }
                Button("Actual Size") {
                    viewModel.selectedDocument?.zoom = 1
                }
            }
            Spacer()
            Button("Save") {
                viewModel.save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedDocument == nil)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct FormattingBarView: View {
    @ObservedObject var document: DocumentModel

    private let fontFamilies = ["SF Mono", "Menlo", "Monaco", "Courier New", "Helvetica", "Arial", "Times New Roman"]
    private let fontSizes: [CGFloat] = [10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64, 72]

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(fontFamilies, id: \.self) { family in
                    Button(family) { changeFontFamily(to: family) }
                }
                Divider()
                Button("Show Fonts…") {
                    NSFontManager.shared.orderFrontFontPanel(nil)
                }
            } label: {
                Text(document.font.familyName ?? document.font.fontName)
                    .frame(minWidth: 110, alignment: .leading)
            }
            .frame(width: 145)

            Menu {
                ForEach(fontSizes, id: \.self) { size in
                    Button("\(Int(size)) pt") { changeFontSize(to: size) }
                }
            } label: {
                Text("\(Int(document.font.pointSize)) pt")
            }
            .frame(width: 72)

            Divider().frame(height: 22)

            Button {
                toggleTrait(.boldFontMask)
            } label: {
                Image(systemName: "bold")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .background(hasTrait(.boldFontMask) ? Color.accentColor.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .help("Bold")

            Button {
                toggleTrait(.italicFontMask)
            } label: {
                Image(systemName: "italic")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .background(hasTrait(.italicFontMask) ? Color.accentColor.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .help("Italic")

            ColorPicker("Text Color", selection: Binding(
                get: { Color(nsColor: document.textColor) },
                set: { document.textColor = NSColor($0) }
            ))
            .labelsHidden()
            .help("Text Color")

            Divider().frame(height: 22)

            Button {
                document.wordWrap.toggle()
            } label: {
                Image(systemName: "text.word.spacing")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .background(document.wordWrap ? Color.accentColor.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .help("Word Wrap")

            Spacer()

            Button {
                document.zoom = max(document.zoom - 0.1, 0.5)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Text("\(Int(document.zoom * 100))%")
                .monospacedDigit()
                .frame(width: 48)

            Button {
                document.zoom = min(document.zoom + 0.1, 5)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func changeFontFamily(to family: String) {
        let manager = NSFontManager.shared
        let converted = manager.convert(document.font, toFamily: family)
        if converted.familyName == family {
            document.font = converted
        } else if let font = NSFont(name: family, size: document.font.pointSize) {
            document.font = font
        }
    }

    private func changeFontSize(to size: CGFloat) {
        document.font = document.font.withSize(size)
    }

    private func hasTrait(_ trait: NSFontTraitMask) -> Bool {
        NSFontManager.shared.traits(of: document.font).contains(trait)
    }

    private func toggleTrait(_ trait: NSFontTraitMask) {
        let manager = NSFontManager.shared
        if hasTrait(trait) {
            document.font = manager.convert(document.font, toNotHaveTrait: trait)
        } else {
            document.font = manager.convert(document.font, toHaveTrait: trait)
        }
    }
}

struct TabStripView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.documents) { document in
                        DocumentTabView(
                            title: document.tabTitle,
                            isDirty: document.isDirty,
                            isSelected: viewModel.selectedDocumentID == document.id,
                            select: { viewModel.selectedDocumentID = document.id },
                            close: { viewModel.closeTab(document.id) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            Button {
                viewModel.newTab()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("New Tab")
            .padding(.trailing, 8)
        }
        .frame(height: 48)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct DocumentTabView: View {
    let title: String
    let isDirty: Bool
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: select) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(isDirty
                              ? Color(nsColor: .systemOrange)
                              : Color.clear)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(title)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                }
                .frame(minWidth: 118, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .background(
                        Color(nsColor: isSelected ? .tertiaryLabelColor : .separatorColor)
                            .opacity(0.12),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .help("Close Tab")
        }
        .foregroundStyle(
            Color(nsColor: .labelColor)
        )
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            Color(nsColor: isSelected ? .unemphasizedSelectedContentBackgroundColor : .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(nsColor: isSelected ? .secondaryLabelColor : .separatorColor),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.05),
                radius: isSelected ? 3 : 1,
                y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isSelected ? "\(title), selected tab" : "\(title), tab")
    }
}

struct FindReplaceView: View {
    @ObservedObject var viewModel: EditorViewModel
    @FocusState private var findFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                TextField("Find", text: $viewModel.findText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .focused($findFocused)
                    .onSubmit { viewModel.findNext() }
                    .onChange(of: viewModel.findText) { _ in viewModel.updateMatches() }
                Text("\(viewModel.matchIndex) of \(viewModel.matchCount)")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 62)
                Button { viewModel.findNext(backwards: true) } label: {
                    Image(systemName: "chevron.up")
                }
                Button { viewModel.findNext() } label: {
                    Image(systemName: "chevron.down")
                }
                Toggle("Aa", isOn: $viewModel.caseSensitive)
                    .toggleStyle(.button)
                    .help("Match Case")
                    .onChange(of: viewModel.caseSensitive) { _ in viewModel.updateMatches() }
                Toggle("Word", isOn: $viewModel.wholeWord)
                    .toggleStyle(.button)
                    .help("Whole Word")
                    .onChange(of: viewModel.wholeWord) { _ in viewModel.updateMatches() }
                Button {
                    viewModel.isFindPresented = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            if viewModel.isReplacePresented {
                HStack(spacing: 6) {
                    TextField("Replace with", text: $viewModel.replaceText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    Button("Replace") { viewModel.replaceCurrent() }
                    Button("Replace All") { viewModel.replaceAll() }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8, y: 3)
        .onAppear { findFocused = true }
    }
}

struct StatusBarView: View {
    @ObservedObject var document: DocumentModel

    var body: some View {
        let position = document.lineAndColumn
        HStack(spacing: 0) {
            Text("Ln \(position.0), Col \(position.1)")
            Divider().padding(.horizontal, 14)
            if document.selectedRange.length > 0 {
                Text("\(document.selectedRange.length) selected")
            } else {
                Text("\(document.text.count) characters · \(document.wordCount) words")
            }
            Spacer()
            Menu("\(Int(document.zoom * 100))%") {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 5], id: \.self) { zoom in
                    Button("\(Int(zoom * 100))%") { document.zoom = zoom }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 74)
            Divider().padding(.horizontal, 14)
            Menu(document.lineEnding.rawValue) {
                ForEach(LineEnding.allCases) { ending in
                    Button(ending.rawValue) { document.lineEnding = ending; document.isDirty = true }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 145)
            Divider().padding(.horizontal, 14)
            Menu(document.encoding.rawValue) {
                ForEach(TextEncoding.allCases) { encoding in
                    Button(encoding.rawValue) { document.encoding = encoding; document.isDirty = true }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 120)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct CommandReceiver: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .notepadNewTab)) { _ in viewModel.newTab() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadOpen)) { _ in viewModel.open() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadSave)) { _ in viewModel.save() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadSaveAs)) { _ in viewModel.saveAs() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadFind)) { _ in viewModel.showFind() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadReplace)) { _ in viewModel.showFind(replace: true) }
            .onReceive(NotificationCenter.default.publisher(for: .notepadGoToLine)) { _ in viewModel.goToLine() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadInsertDateTime)) { _ in viewModel.insertDateTime() }
            .onReceive(NotificationCenter.default.publisher(for: .notepadPrint)) { _ in viewModel.printDocument() }
    }
}

struct EditorAlerts: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel

    private var externalChangeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedDocument?.externalChangeDetected == true },
            set: { if !$0 { viewModel.keepMine() } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert("File Changed", isPresented: externalChangeBinding) {
                Button("Reload") { viewModel.reloadExternalChange() }
                Button("Keep Mine", role: .cancel) { viewModel.keepMine() }
            } message: {
                Text("This file was changed by another application.")
            }
            .alert("Couldn’t Complete the Operation", isPresented: errorBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }
}

extension Notification.Name {
    static let notepadNewTab = Notification.Name("Notepad.NewTab")
    static let notepadOpen = Notification.Name("Notepad.Open")
    static let notepadSave = Notification.Name("Notepad.Save")
    static let notepadSaveAs = Notification.Name("Notepad.SaveAs")
    static let notepadFind = Notification.Name("Notepad.Find")
    static let notepadReplace = Notification.Name("Notepad.Replace")
    static let notepadGoToLine = Notification.Name("Notepad.GoToLine")
    static let notepadInsertDateTime = Notification.Name("Notepad.InsertDateTime")
    static let notepadPrint = Notification.Name("Notepad.Print")
}

#Preview {
    ContentView()
}
