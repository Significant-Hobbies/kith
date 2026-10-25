import Foundation
import XCTest

@testable import KithCore

final class LocalInteractionMetricsTests: XCTestCase {
    func testDailyCountersAndElapsedSamplesAreContentFreeAndDeviceLocal() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appending(path: "kith-v1.json")
        let metricsURL = root.appending(path: "interaction-metrics-v1.json")
        let store = KithInteractionMetricsStore(fileURL: metricsURL)
        let first = Date(timeIntervalSince1970: 1_798_000_000)
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        try await store.record(.searchAttempt(hasResults: false), at: first, timeZone: zone)
        try await store.record(.searchAttempt(hasResults: true), at: first.addingTimeInterval(20), timeZone: zone)
        try await store.record(.resultOpened, at: first.addingTimeInterval(30), timeZone: zone)
        try await store.record(.logEditorOpened, at: first.addingTimeInterval(40), timeZone: zone)
        try await store.record(.logSaveSucceeded(elapsedSeconds: 18.5), at: first.addingTimeInterval(60), timeZone: zone)
        try await store.record(.logSaveFailed(elapsedSeconds: 4), at: first.addingTimeInterval(80), timeZone: zone)
        try await store.record(.logCanceled(elapsedSeconds: 0), at: first.addingTimeInterval(100), timeZone: zone)
        try await store.record(.logAbandoned, at: first.addingTimeInterval(120), timeZone: zone)

        let journal = KithStore(fileURL: journalURL)
        let actualMetricsURL = await store.fileURL
        let actualJournalURL = journal.fileURL
        XCTAssertNotEqual(actualMetricsURL.standardizedFileURL, actualJournalURL.standardizedFileURL)

        let loadedDocument = try await store.load()
        let document = try XCTUnwrap(loadedDocument)
        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.projectId, "kith")
        XCTAssertEqual(document.timeZoneIdentifier, zone.identifier)
        XCTAssertEqual(document.days.count, 1)
        let day = try XCTUnwrap(document.days.first)
        XCTAssertEqual(day.counters, [
            "search_attempt": 2,
            "search_no_results": 1,
            "result_opened": 1,
            "log_editor_opened": 1,
            "log_save_succeeded": 1,
            "log_save_failed": 1,
            "log_canceled": 1,
            "log_abandoned": 1,
        ])
        XCTAssertEqual(day.durationTotalsSeconds, ["log_editor_foreground_elapsed": 22.5])
        XCTAssertEqual(day.durationSamples, ["log_editor_foreground_elapsed": 3])

        let encoded = try Data(contentsOf: metricsURL)
        let rootObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(rootObject.keys), Set([
            "schemaVersion", "projectId", "coverageStartedAtISO", "updatedAtISO",
            "timeZoneIdentifier", "days",
        ]))
        let days = try XCTUnwrap(rootObject["days"] as? [[String: Any]])
        let dayObject = try XCTUnwrap(days.first)
        XCTAssertEqual(Set(dayObject.keys), Set(["date", "counters", "durationTotalsSeconds", "durationSamples"]))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("personID"))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("note"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: journalURL.path))
    }

    func testDailyRowsRetainHistoryAndUseLocalCalendarDate() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithInteractionMetricsStore(fileURL: root.appending(path: "interaction-metrics-v1.json"))
        let zone = try XCTUnwrap(TimeZone(identifier: "Pacific/Kiritimati"))
        let beforeMidnight = ISO8601DateFormatter().date(from: "2026-10-24T09:59:00Z")!
        let afterMidnight = ISO8601DateFormatter().date(from: "2026-10-24T10:01:00Z")!

        try await store.record(.resultOpened, at: beforeMidnight, timeZone: zone)
        try await store.record(.resultOpened, at: afterMidnight, timeZone: zone)
        let loadedDocument = try await store.load()
        let document = try XCTUnwrap(loadedDocument)

        XCTAssertEqual(document.days.map(\.date), ["2026-10-24", "2026-10-25"])
        XCTAssertEqual(document.days.compactMap { $0.counters["result_opened"] }, [1, 1])
        XCTAssertEqual(document.coverageStartedAtISO, "2026-10-24T09:59:00Z")
    }

    func testInvalidExistingSidecarIsPreservedWhenOptionalMetricWriteFails() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "interaction-metrics-v1.json")
        let corruptData = Data("not valid metrics json".utf8)
        try corruptData.write(to: file)
        let store = KithInteractionMetricsStore(fileURL: file)

        do {
            try await store.record(.resultOpened)
            XCTFail("A malformed sidecar must not be replaced by a new report")
        } catch {
            XCTAssertEqual(try Data(contentsOf: file), corruptData)
        }
    }
}
