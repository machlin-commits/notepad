import Foundation

final class RecoveryService {
    static let shared = RecoveryService()
    private var pending: [UUID: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "Notepad.Recovery", qos: .utility)

    private var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Windows Notepad for Mac/Recovery", isDirectory: true)
    }

    func schedule(_ snapshot: DocumentSnapshot) {
        pending[snapshot.id]?.cancel()
        let item = DispatchWorkItem { [directory] in
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: directory.appendingPathComponent("\(snapshot.id).json"), options: .atomic)
            } catch {
                NSLog("Recovery snapshot failed: %@", error.localizedDescription)
            }
        }
        pending[snapshot.id] = item
        queue.asyncAfter(deadline: .now() + 1, execute: item)
    }

    func remove(id: UUID) {
        pending[id]?.cancel()
        pending[id] = nil
        queue.async { [directory] in
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).json"))
        }
    }

    func recoveredSnapshots() -> [DocumentSnapshot] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(DocumentSnapshot.self, from: data)
        }.sorted { $0.date < $1.date }
    }
}
