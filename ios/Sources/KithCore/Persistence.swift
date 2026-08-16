import Foundation

public enum KithFiles {
    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Kith", directoryHint: .isDirectory)
    }

    public static var document: URL {
        supportDirectory.appending(path: "kith-v1.json")
    }
}

public actor KithStore {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? KithFiles.document
    }

    public func load() throws -> KithDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.migrate(Self.decode(data))
    }

    public func save(_ document: KithDocument) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encode(document).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public static func encode(_ document: KithDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> KithDocument {
        try decoder.decode(KithDocument.self, from: data)
    }

    static func migrate(_ document: KithDocument) throws -> KithDocument {
        guard document.schemaVersion <= KithDocument.currentSchemaVersion else {
            throw KithError.unsupportedSchema(document.schemaVersion)
        }
        guard document.schemaVersion < KithDocument.currentSchemaVersion else { return document }
        var migrated = document
        migrated.schemaVersion = KithDocument.currentSchemaVersion
        return migrated
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
