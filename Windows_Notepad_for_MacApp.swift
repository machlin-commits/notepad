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

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                NotificationCenter.default.post(name: .notepadNewTab, object: nil)
            }
            .keyboardShortcut("t")

            Button("New Window") {
                openWindow(id: "editor")
            }
            .keyboardShortcut("n")

            Divider()

            Button("Open…") {
                NotificationCenter.default.post(name: .notepadOpen, object: nil)
            }
            .keyboardShortcut("o")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                NotificationCenter.default.post(name: .notepadSave, object: nil)
            }
            .keyboardShortcut("s")

            Button("Save As…") {
                NotificationCenter.default.post(name: .notepadSaveAs, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(after: .saveItem) {
            Button("Print…") {
                NotificationCenter.default.post(name: .notepadPrint, object: nil)
            }
            .keyboardShortcut("p")
        }

        CommandGroup(after: .textEditing) {
            Divider()
            Button("Find…") {
                NotificationCenter.default.post(name: .notepadFind, object: nil)
            }
            .keyboardShortcut("f")

            Button("Find and Replace…") {
                NotificationCenter.default.post(name: .notepadReplace, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("Go to Line…") {
                NotificationCenter.default.post(name: .notepadGoToLine, object: nil)
            }
            .keyboardShortcut("l")

            Divider()

            Button("Insert Date and Time") {
                NotificationCenter.default.post(name: .notepadInsertDateTime, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character("\u{F708}")), modifiers: [])
        }
    }
}
