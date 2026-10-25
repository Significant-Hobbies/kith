import Foundation

/// A content-free interaction proxy. These values describe app actions, not
/// whether a memory was useful or a recall succeeded.
/// Each log outcome duration covers the foreground segment since the previous
/// outcome; a failed save ends one effort sample and a retry starts another.
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

private enum KithInteractionMetricsError: Error {
    case counterOverflow
    case durationOverflow
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
        try Self.apply(metric, to: &day)
        current.days.removeAll(where: { $0.date == dayKey })
        current.days.append(day)
        current.days.sort { $0.date < $1.date }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(current).write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var metricsURL = fileURL
        try metricsURL.setResourceValues(resourceValues)
    }

    public func load() throws -> KithInteractionMetricsDocument? {
        try loadIfPresent()
    }

    private func loadIfPresent() throws -> KithInteractionMetricsDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try Self.decoder.decode(KithInteractionMetricsDocument.self, from: Data(contentsOf: fileURL))
    }

    private static func apply(_ metric: KithInteractionMetric, to day: inout KithDailyInteractionMetrics) throws {
        switch metric {
        case let .searchAttempt(hasResults):
            try increment("search_attempt", in: &day.counters)
            if !hasResults { try increment("search_no_results", in: &day.counters) }
        case .resultOpened:
            try increment("result_opened", in: &day.counters)
        case .logEditorOpened:
            try increment("log_editor_opened", in: &day.counters)
        case let .logSaveSucceeded(elapsedSeconds):
            try recordLogOutcome("log_save_succeeded", elapsedSeconds: elapsedSeconds, in: &day)
        case let .logSaveFailed(elapsedSeconds):
            try recordLogOutcome("log_save_failed", elapsedSeconds: elapsedSeconds, in: &day)
        case let .logCanceled(elapsedSeconds):
            try recordLogOutcome("log_canceled", elapsedSeconds: elapsedSeconds, in: &day)
        case .logAbandoned:
            try increment("log_abandoned", in: &day.counters)
        }
    }

    private static func recordLogOutcome(
        _ counter: String,
        elapsedSeconds: TimeInterval,
        in day: inout KithDailyInteractionMetrics
    ) throws {
        try increment(counter, in: &day.counters)
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else { return }
        let durationKey = "log_editor_foreground_elapsed"
        let total = (day.durationTotalsSeconds[durationKey] ?? 0) + elapsedSeconds
        guard total.isFinite else { throw KithInteractionMetricsError.durationOverflow }
        day.durationTotalsSeconds[durationKey] = total
        try increment(durationKey, in: &day.durationSamples)
    }

    private static func increment(_ key: String, in counters: inout [String: Int]) throws {
        let (next, overflow) = counters[key, default: 0].addingReportingOverflow(1)
        guard !overflow else { throw KithInteractionMetricsError.counterOverflow }
        counters[key] = next
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
