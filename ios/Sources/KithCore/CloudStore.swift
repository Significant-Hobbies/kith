import CloudKit
import Foundation

public enum CloudAvailability: Equatable, Sendable {
    case available
    case noAccount
    case unavailable(String)
}

/// One JSON document in the owner's private iCloud database.
///
/// The container is on Sarthak's personal team (`8F7LXHTJZR`). There is no
/// Kith server and no public or shared CloudKit zone.
public actor KithCloudStore {
    public static let containerIdentifier = "iCloud.com.significanthobbies.kith"

    private static let recordType = "KithDocument"
    private static let recordName = "current"
    private static let payloadKey = "payload"

    private let container: CKContainer

    public init(containerIdentifier: String = containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
    }

    public func availability() async -> CloudAvailability {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .unavailable("iCloud is restricted on this device")
            case .couldNotDetermine:
                return .unavailable("iCloud status could not be determined")
            case .temporarilyUnavailable:
                return .unavailable("iCloud is temporarily unavailable")
            @unknown default:
                return .unavailable("Unrecognised iCloud status")
            }
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    public func fetch() async throws -> KithDocument? {
        let recordID = CKRecord.ID(recordName: Self.recordName)
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            guard let data = record[Self.payloadKey] as? Data else { return nil }
            return try KithStore.decode(data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    public func save(_ document: KithDocument) async throws {
        let recordID = CKRecord.ID(recordName: Self.recordName)
        let record: CKRecord
        do {
            record = try await container.privateCloudDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }
        record[Self.payloadKey] = try KithStore.encode(document) as CKRecordValue
        _ = try await container.privateCloudDatabase.save(record)
    }
}
