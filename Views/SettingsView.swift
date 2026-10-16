import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettingsPane()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            EditingSettingsPane()
                .tabItem { Label("Editing", systemImage: "text.cursor") }
            FilesSettingsPane()
                .tabItem { Label("Files", systemImage: "doc") }
            PrivacySettingsPane()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(20)
        .frame(width: 560, height: 330)
    }
}

struct GeneralSettingsPane: View {
    @AppStorage("restoreSession") private var restoreSession = true

    var body: some View {
        Form {
            Toggle("Restore windows and tabs when Notepad opens", isOn: $restoreSession)
            Text("Unsaved documents are protected by local recovery snapshots.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AppearanceSettingsPane: View {
    @AppStorage("appearance") private var appearance = "System"

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }
}

struct EditingSettingsPane: View {
    @AppStorage("checkSpelling") private var checkSpelling = true
    @AppStorage("defaultWordWrap") private var defaultWordWrap = true

    var body: some View {
        Form {
            Toggle("Check spelling while typing", isOn: $checkSpelling)
            Toggle("Wrap text by default", isOn: $defaultWordWrap)
        }
        .padding()
    }
}

struct FilesSettingsPane: View {
    @AppStorage("defaultEncoding") private var defaultEncoding = TextEncoding.utf8.rawValue
    @AppStorage("defaultLineEnding") private var defaultLineEnding = LineEnding.lf.rawValue

    var body: some View {
        Form {
            Picker("Default encoding", selection: $defaultEncoding) {
                ForEach(TextEncoding.allCases) { encoding in Text(encoding.rawValue).tag(encoding.rawValue) }
            }
            Picker("Default line endings", selection: $defaultLineEnding) {
                ForEach(LineEnding.allCases) { ending in Text(ending.rawValue).tag(ending.rawValue) }
            }
        }
        .padding()
    }
}

struct PrivacySettingsPane: View {
    var body: some View {
        Form {
            Label("Notepad makes no network requests.", systemImage: "network.slash")
            Label("No analytics or telemetry is collected.", systemImage: "chart.bar.xaxis")
            Text("File access is limited to files you select.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
