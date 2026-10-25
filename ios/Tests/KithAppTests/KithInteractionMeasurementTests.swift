import Foundation
import KithCore
import XCTest

@testable import Kith

@MainActor
final class KithInteractionMeasurementTests: XCTestCase {
    func testSearchAndExplicitVisibleResultOpenWriteOnlyContentFreeProxies() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appending(path: "kith-v1.json")
        let metricsURL = root.appending(path: "interaction-metrics-v1.json")
        let person = Person(name: "Private Person Sentinel", standingNotes: "Private note sentinel")
        let model = AppModel(store: KithStore(fileURL: journalURL), cloud: nil, mirror: nil)

        await model.load()
        await model.recordSearchAttempt() // Empty field is not a search attempt.
        let personSaved = await model.savePerson(person)
        XCTAssertTrue(personSaved)
        model.selectedPersonID = nil
        model.searchText = "Private Query Sentinel"
        await model.recordSearchAttempt()
        await model.recordSearchAttempt() // A committed search is counted once per edit session.
        await model.openVisibleResult(person.id) // A non-visible result is ignored.
        XCTAssertNil(model.selectedPersonID)
        model.searchText = "Private Person Sentinel"
        XCTAssertNil(model.selectedPersonID, "A search attempt is not a result open")
        await model.openVisibleResult(person.id)
        XCTAssertEqual(model.selectedPersonID, person.id)

        let loadedMetrics = try await KithInteractionMetricsStore(fileURL: metricsURL).load()
        let savedMetrics = try XCTUnwrap(loadedMetrics)
        XCTAssertEqual(savedMetrics.days.count, 1)
        XCTAssertEqual(savedMetrics.days[0].counters, [
            "search_attempt": 2,
            "search_no_results": 1,
            "result_opened": 1,
        ])
        let metricsText = String(decoding: try Data(contentsOf: metricsURL), as: UTF8.self)
        XCTAssertFalse(metricsText.contains("Private Query Sentinel"))
        XCTAssertFalse(metricsText.contains("Private Person Sentinel"))
        XCTAssertFalse(metricsText.contains("Private note sentinel"))
        XCTAssertFalse(metricsText.contains(person.id.uuidString))
        XCTAssertTrue(FileManager.default.fileExists(atPath: journalURL.path))
    }

    func testEditorAbandonmentDropsTimeAndForegroundSaveExcludesBackground() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            store: KithStore(fileURL: root.appending(path: "kith-v1.json")),
            cloud: nil,
            mirror: nil
        )
        await model.load()
        let startedAt = Date(timeIntervalSince1970: 1_798_000_000)
        model.beginLogEditorMeasurement(at: startedAt)
        model.setMeasurementAppActive(false, at: startedAt.addingTimeInterval(20))
        model.setMeasurementAppActive(true, at: startedAt.addingTimeInterval(3_620))
        model.finishLogEditorMeasurement(.abandoned, at: startedAt.addingTimeInterval(3_630))

        let nextStart = startedAt.addingTimeInterval(4_000)
        model.beginLogEditorMeasurement(at: nextStart)
        model.setMeasurementAppActive(false, at: nextStart.addingTimeInterval(10))
        model.setMeasurementAppActive(true, at: nextStart.addingTimeInterval(3_610))
        model.finishLogEditorMeasurement(.saved, at: nextStart.addingTimeInterval(3_625))

        let metricsURL = root.appending(path: "interaction-metrics-v1.json")
        let loadedMetrics = try await waitForMetrics(
            at: metricsURL,
            counters: ["log_editor_opened": 2, "log_abandoned": 1, "log_save_succeeded": 1]
        )
        let savedMetrics = try XCTUnwrap(loadedMetrics)
        let day = try XCTUnwrap(savedMetrics.days.first)
        XCTAssertEqual(day.counters, [
            "log_editor_opened": 2,
            "log_abandoned": 1,
            "log_save_succeeded": 1,
        ])
        XCTAssertEqual(day.durationTotalsSeconds, ["log_editor_foreground_elapsed": 25])
        XCTAssertEqual(day.durationSamples, ["log_editor_foreground_elapsed": 1])
        XCTAssertFalse(String(decoding: try Data(contentsOf: metricsURL), as: UTF8.self).contains("useful_recall"))
        XCTAssertFalse(String(decoding: try Data(contentsOf: metricsURL), as: UTF8.self).contains("failed_retrieval"))
    }

    private func waitForMetrics(
        at url: URL,
        counters expected: [String: Int]
    ) async throws -> KithInteractionMetricsDocument? {
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: url),
               let document = try? JSONDecoder().decode(KithInteractionMetricsDocument.self, from: data),
               let day = document.days.first,
               expected.allSatisfy({ day.counters[$0.key] == $0.value }) {
                return document
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return try await KithInteractionMetricsStore(fileURL: url).load()
    }
}
