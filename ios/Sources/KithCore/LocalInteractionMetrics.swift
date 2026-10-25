import Foundation

/// A content-free interaction proxy. These values describe app actions, not
/// whether a memory was useful or a recall succeeded.
public enum KithInteractionMetric: Sendable {
    case searchAttempt(hasResults: Bool)
    case resultOpened
    case logEditorOpened
    case logSaveSucceeded(elapsedSeconds: TimeInterval)
    case logSaveFailed(elapsedSeconds: TimeInterval)
    case logCanceled(elapsedSeconds: TimeInterval)
    case logAbandoned
}

public struct KithDailyInteractionMetrics: Codable, Equatable, Sendable {
    public var date: String
    public var counters: [String: Int]
    public var durationTotalsSeconds: [String: Double]
    public var durationSamples: [String: Int]

    public init(
        date: String,
        counters: [String: Int] = [:],
        durationTotalsSeconds: [String: Double] = [:],
        durationSamples: [String: Int] = [:]
    ) {
        self.date = date
        self.counters = counters
        self.durationTotalsSeconds = durationTotalsSeconds
        self.durationSamples = durationSamples
    }
}

/// Device-only daily counters. This sidecar is deliberately separate from
/// `kith-v1.json`, the CloudKit mirror, and PersonalSyncKit projections.
public struct KithInteractionMetricsDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var projectId: String
    public var coverageStartedAtISO: String
    public var updatedAtISO: String
    public var timeZoneIdentifier: String
    public var days: [KithDailyInteractionMetrics]

    public init(
        coverageStartedAtISO: String,
        updatedAtISO: String,
        timeZoneIdentifier: String,
        days: [KithDailyInteractionMetrics]
    ) {
        schemaVersion = 1
        projectId = "kith"
        self.coverageStartedAtISO = coverageStartedAtISO
        self.updatedAtISO = updatedAtISO
        self.timeZoneIdentifier = timeZoneIdentifier
        self.days = days
    }
}

/// Persists only fixed event counters and elapsed-time aggregates. The
/// injectable URL keeps unit/UI fixtures away from the owner's app-support data.
public actor KithInteractionMetricsStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func record(
        _ metric: KithInteractionMetric,
        at date: Date = .now,
        timeZone: TimeZone = .current
    ) throws {
        let dayKey = Self.dayKey(for: date, timeZone: timeZone)
        let timestamp = Self.timestamp(for: date)
        var document = try loadIfPresent()

        if document == nil {
            document = KithInteractionMetricsDocument(
                coverageStartedAtISO: timestamp,
                updatedAtISO: timestamp,
                timeZoneIdentifier: timeZone.identifier,
                days: []
            )
        }

        guard var current = document else { return }
        current.updatedAtISO = timestamp
        current.timeZoneIdentifier = timeZone.identifier

        var day = current.days.first(where: { $0.date == dayKey })
            ?? KithDailyInteractionMetrics(date: dayKey)
        Self.apply(metric, to: &day)
        current.days.removeAll(where: { $0.date == dayKey })
        current.days.append(day)
        current.days.sort { $0.date < $1.date }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(current).write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
    }

    public func load() throws -> KithInteractionMetricsDocument? {
        try loadIfPresent()
    }

    private func loadIfPresent() throws -> KithInteractionMetricsDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try Self.decoder.decode(KithInteractionMetricsDocument.self, from: Data(contentsOf: fileURL))
    }

    private static func apply(_ metric: KithInteractionMetric, to day: inout KithDailyInteractionMetrics) {
        switch metric {
        case let .searchAttempt(hasResults):
            increment("search_attempt", in: &day.counters)
            if !hasResults { increment("search_no_results", in: &day.counters) }
        case .resultOpened:
            increment("result_opened", in: &day.counters)
        case .logEditorOpened:
            increment("log_editor_opened", in: &day.counters)
        case let .logSaveSucceeded(elapsedSeconds):
            recordLogOutcome("log_save_succeeded", elapsedSeconds: elapsedSeconds, in: &day)
        case let .logSaveFailed(elapsedSeconds):
            recordLogOutcome("log_save_failed", elapsedSeconds: elapsedSeconds, in: &day)
        case let .logCanceled(elapsedSeconds):
            recordLogOutcome("log_canceled", elapsedSeconds: elapsedSeconds, in: &day)
        case .logAbandoned:
            increment("log_abandoned", in: &day.counters)
        }
    }

    private static func recordLogOutcome(
        _ counter: String,
        elapsedSeconds: TimeInterval,
        in day: inout KithDailyInteractionMetrics
    ) {
        increment(counter, in: &day.counters)
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else { return }
        day.durationTotalsSeconds["log_editor_foreground_elapsed"] =
            (day.durationTotalsSeconds["log_editor_foreground_elapsed"] ?? 0) + elapsedSeconds
        increment("log_editor_foreground_elapsed", in: &day.durationSamples)
    }

    private static func increment(_ key: String, in counters: inout [String: Int]) {
        counters[key, default: 0] += 1
    }

    private static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func timestamp(for date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}
