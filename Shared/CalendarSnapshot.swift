import Foundation

enum SharedCalendarData {
    static let snapshotFileName = "week-calendar-snapshot.json"
    static let snapshotKey = "weekCalendarSnapshot"
    static let selectedCalendarIDsKey = "selectedCalendarIDs"
    static let visibleWeekOffsetKey = "visibleWeekOffset"

    static var widgetBundleID: String {
        if let configuredID = Bundle.main.object(forInfoDictionaryKey: "CalendarWeekWidgetBundleIdentifier") as? String,
           !configuredID.isEmpty {
            return configuredID
        }

        if let bundleID = Bundle.main.bundleIdentifier {
            return bundleID.hasSuffix(".widget") ? bundleID : "\(bundleID).widget"
        }

        return "com.example.calendarweek.widget"
    }

    static var urlScheme: String {
        if let configuredScheme = Bundle.main.object(forInfoDictionaryKey: "CalendarWeekURLScheme") as? String,
           !configuredScheme.isEmpty {
            return configuredScheme
        }

        return "calendarweek"
    }

    static var openCalendarURL: URL? {
        URL(string: "\(urlScheme)://open-calendar")
    }

    static var defaults: UserDefaults {
        .standard
    }

    static var sharedContainerURL: URL? {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let widgetContainerSuffix = "/Library/Containers/\(widgetBundleID)/Data"

        if homeURL.path.hasSuffix(widgetContainerSuffix) {
            return homeURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("MacCalendarWeek", isDirectory: true)
        }

        return homeURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent(widgetBundleID, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("MacCalendarWeek", isDirectory: true)
    }

    static var snapshotURL: URL? {
        sharedContainerURL?.appendingPathComponent(snapshotFileName, isDirectory: false)
    }

    static func loadSnapshot() -> WeekSnapshot? {
        if let snapshotURL, let data = try? Data(contentsOf: snapshotURL), let snapshot = try? JSONDecoder.calendarSnapshot.decode(WeekSnapshot.self, from: data) {
            return snapshot
        }

        guard let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }

        return try? JSONDecoder.calendarSnapshot.decode(WeekSnapshot.self, from: data)
    }

    static func snapshotReadStatus() -> String {
        guard let snapshotURL else {
            return "Widget container unavailable"
        }

        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            return "Snapshot file missing"
        }

        do {
            let data = try Data(contentsOf: snapshotURL)
            _ = try JSONDecoder.calendarSnapshot.decode(WeekSnapshot.self, from: data)
            return "Snapshot file readable"
        } catch {
            return "Snapshot decode failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    static func saveSnapshot(_ snapshot: WeekSnapshot) -> Bool {
        guard let data = try? JSONEncoder.calendarSnapshot.encode(snapshot) else {
            return false
        }

        defaults.set(data, forKey: snapshotKey)

        guard let snapshotURL else {
            return false
        }

        do {
            try FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: snapshotURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func loadSelectedCalendarIDs() -> Set<String> {
        let ids = defaults.stringArray(forKey: selectedCalendarIDsKey) ?? []
        return Set(ids)
    }

    static func saveSelectedCalendarIDs(_ ids: Set<String>) {
        defaults.set(Array(ids).sorted(), forKey: selectedCalendarIDsKey)
    }

    static func loadVisibleWeekOffset() -> Int {
        defaults.integer(forKey: visibleWeekOffsetKey)
    }

    static func saveVisibleWeekOffset(_ offset: Int) {
        defaults.set(max(-8, min(8, offset)), forKey: visibleWeekOffsetKey)
    }

    static func changeVisibleWeekOffset(by delta: Int) {
        saveVisibleWeekOffset(loadVisibleWeekOffset() + delta)
    }

    static func resetVisibleWeekOffset() {
        saveVisibleWeekOffset(0)
    }
}

struct WeekSnapshot: Codable, Equatable {
    var generatedAt: Date
    var weekStart: Date
    var calendars: [CalendarDigest]
    var events: [CalendarEventDigest]
}

struct CalendarDigest: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var sourceTitle: String?
    var colorHex: String
    var isSelected: Bool
}

struct CalendarEventDigest: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var calendarID: String
    var calendarTitle: String
    var colorHex: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
}

extension Calendar {
    static var sundayFirstGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 1
        return calendar
    }

    func sundayFirstWeekStart(containing date: Date) -> Date {
        let startOfDay = startOfDay(for: date)
        let weekday = component(.weekday, from: startOfDay)
        let daysFromSunday = (weekday - firstWeekday + 7) % 7
        return self.date(byAdding: .day, value: -daysFromSunday, to: startOfDay) ?? startOfDay
    }
}

extension JSONEncoder {
    static var calendarSnapshot: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var calendarSnapshot: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
