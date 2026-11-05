import Foundation

/// Shared between the app and the share extension.
enum AppGroup {
    /// Read from Info.plist (`PressedAppGroup`) so project.yml is the only place to edit.
    static var identifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "PressedAppGroup") as? String) ?? "group.com.example.pressed"
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// A link saved from the share extension, waiting for the app to pick it up.
struct InboxItem: Codable {
    let id: UUID
    let urlString: String
    let savedAt: Date
    let sealSeed: Int32
}

/// One small JSON file per saved link; the app imports and deletes them on launch and foreground.
enum Inbox {
    private static var directory: URL? {
        guard let base = AppGroup.containerURL else { return nil }
        let dir = base.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    enum InboxError: Error { case noContainer }

    static func write(_ item: InboxItem) throws {
        guard let dir = directory else { throw InboxError.noContainer }
        let data = try encoder.encode(item)
        try data.write(to: dir.appendingPathComponent("\(item.id.uuidString).json"), options: .atomic)
    }

    /// Returns every readable item with its file URL. Unreadable files are deleted.
    static func readAll() -> [(file: URL, item: InboxItem)] {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { return [] }
        var result: [(file: URL, item: InboxItem)] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file), let item = try? decoder.decode(InboxItem.self, from: data) {
                result.append((file, item))
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }
        return result.sorted { $0.item.savedAt < $1.item.savedAt }
    }
}
