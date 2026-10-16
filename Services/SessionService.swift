import Foundation

struct SessionTab: Codable {
    let id: UUID
    let fileURL: URL?
    let displayName: String
    let encoding: TextEncoding
    let lineEnding: LineEnding
    let bookmarkData: Data?
}

enum SessionService {
    private static let key = "Notepad.SessionTabs"

    static func save(_ documents: [DocumentModel]) {
        let tabs = documents.map {
            SessionTab(id: $0.id, fileURL: $0.fileURL, displayName: $0.displayName,
                       encoding: $0.encoding, lineEnding: $0.lineEnding,
                       bookmarkData: $0.bookmarkData)
        }
        if let data = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func restore() -> [SessionTab] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SessionTab].self, from: data)) ?? []
    }
}
