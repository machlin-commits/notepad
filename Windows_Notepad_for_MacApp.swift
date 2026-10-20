import SwiftUI

@main
struct Windows_Notepad_for_MacApp: App {
    var body: some Scene {
        WindowGroup(id: "editor") {
            ContentView()
        }
        .defaultSize(width: 1000, height: 680)
        .commands {
            NotepadCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

struct NotepadCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.editorViewModel) private var viewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                viewModel?.newTab()
            }
            .keyboardShortcut("t")

            Button("New Window") {
                openWindow(id: "editor")
            }
            .keyboardShortcut("n")

            Divider()

            Button("Open…") {
                viewModel?.open()
            }
            .keyboardShortcut("o")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                viewModel?.save()
            }
            .keyboardShortcut("s")

            Button("Save As…") {
                viewModel?.saveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(after: .saveItem) {
            Button("Print…") {
                viewModel?.printDocument()
            }
            .keyboardShortcut("p")
        }

        CommandGroup(after: .toolbar) {
            Button("Word Wrap") { viewModel?.selectedDocument?.wordWrap.toggle() }
            Divider()
            Button("Zoom In") {
                guard let document = viewModel?.selectedDocument else { return }
                document.zoom = min(document.zoom + 0.1, 5)
            }
            .keyboardShortcut("+")
            Button("Zoom Out") {
                guard let document = viewModel?.selectedDocument else { return }
                document.zoom = max(document.zoom - 0.1, 0.5)
            }
            .keyboardShortcut("-")
            Button("Actual Size") { viewModel?.selectedDocument?.zoom = 1 }
                .keyboardShortcut("0")
        }

        CommandGroup(after: .textEditing) {
            Divider()
            Button("Find…") {
                viewModel?.showFind()
            }
            .keyboardShortcut("f")

            Button("Find and Replace…") {
                viewModel?.showFind(replace: true)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("Go to Line…") {
                viewModel?.goToLine()
            }
            .keyboardShortcut("l")

            Divider()

            Button("Insert Date and Time") {
                viewModel?.insertDateTime()
            }
            .keyboardShortcut(KeyEquivalent(Character("\u{F708}")), modifiers: [])
        }
    }
}

private struct EditorViewModelKey: FocusedValueKey {
    typealias Value = EditorViewModel
}

extension FocusedValues {
    var editorViewModel: EditorViewModel? {
        get { self[EditorViewModelKey.self] }
        set { self[EditorViewModelKey.self] = newValue }
    }
}
