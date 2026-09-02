import AppIntents
import SwiftUI
import WidgetKit

struct WeekCalendarEntry: TimelineEntry {
    var date: Date
    var snapshot: WeekSnapshot?
    var weekOffset: Int
}

struct WeekCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekCalendarEntry {
        WeekCalendarEntry(date: Date(), snapshot: .sample, weekOffset: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekCalendarEntry) -> Void) {
        completion(WeekCalendarEntry(date: Date(), snapshot: SharedCalendarData.loadSnapshot() ?? .sample, weekOffset: SharedCalendarData.loadVisibleWeekOffset()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekCalendarEntry>) -> Void) {
        let entry = WeekCalendarEntry(date: Date(), snapshot: SharedCalendarData.loadSnapshot(), weekOffset: SharedCalendarData.loadVisibleWeekOffset())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct ChangeWeekIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Displayed Week"
    static var description = IntentDescription("Changes the week shown by the Calendar Week widget.")

    @Parameter(title: "Week Delta")
    var delta: Int

    init() {
        delta = 0
    }

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        SharedCalendarData.changeVisibleWeekOffset(by: delta)
        WidgetCenter.shared.reloadTimelines(ofKind: "WeekCalendarWidget")
        return .result()
    }
}

struct ResetWeekIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Current Week"
    static var description = IntentDescription("Returns the Calendar Week widget to the current week.")

    func perform() async throws -> some IntentResult {
        SharedCalendarData.resetVisibleWeekOffset()
        WidgetCenter.shared.reloadTimelines(ofKind: "WeekCalendarWidget")
        return .result()
    }
}

struct WeekCalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WeekCalendarEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            WeekCalendarView(snapshot: snapshot, weekOffset: entry.weekOffset, compact: family == .systemMedium)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(SharedCalendarData.openCalendarURL)
        } else {
            EmptyCalendarView()
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(SharedCalendarData.openCalendarURL)
        }
    }
}

struct WeekCalendarView: View {
    var snapshot: WeekSnapshot
    var weekOffset: Int
    var compact: Bool

    private var calendar: Calendar {
        .sundayFirstGregorian
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            header

            HStack(alignment: .top, spacing: compact ? 4 : 6) {
                ForEach(days, id: \.self) { day in
                    DayColumn(
                        day: day,
                        events: events(on: day),
                        compact: compact
                    )
                }
            }
        }
        .padding(compact ? 12 : 16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(monthTitle)
                    .font(compact ? .headline : .title3.bold())
                    .lineLimit(1)

                if !compact {
                    Text(weekTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: compact ? 4 : 6) {
                Button(intent: ChangeWeekIntent(delta: -1)) {
                    Image(systemName: "chevron.left")
                }

                Button(intent: ResetWeekIntent()) {
                    Image(systemName: "calendar.day.timeline.left")
                }

                Button(intent: ChangeWeekIntent(delta: 1)) {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: visibleWeekStart)
        }
    }

    private var visibleWeekStart: Date {
        calendar.date(byAdding: .weekOfYear, value: weekOffset, to: snapshot.weekStart) ?? snapshot.weekStart
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: visibleWeekStart)
    }

    private var weekTitle: String {
        if weekOffset == 0 {
            return "This week"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDate = calendar.date(byAdding: .day, value: 6, to: visibleWeekStart) ?? visibleWeekStart
        return "\(formatter.string(from: visibleWeekStart))-\(formatter.string(from: endDate))"
    }

    private var updateTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Updated \(formatter.string(from: snapshot.generatedAt))"
    }

    private func events(on day: Date) -> [CalendarEventDigest] {
        snapshot.events.filter { event in
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return false
            }

            if event.isAllDay {
                return event.startDate < nextDay && event.endDate > day
            }

            return calendar.isDate(event.startDate, inSameDayAs: day)
        }
    }
}

private struct DayColumn: View {
    var day: Date
    var events: [CalendarEventDigest]
    var compact: Bool

    private var calendar: Calendar {
        .sundayFirstGregorian
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weekday)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(dayNumber)
                    .font(compact ? .callout.bold() : .title3.bold())
                    .foregroundStyle(calendar.isDateInToday(day) ? Color.white : Color.primary)
                    .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                    .background {
                        if calendar.isDateInToday(day) {
                            Circle().fill(Color.primary)
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(displayEvents) { event in
                    EventChip(event: event, day: day, compact: compact)
                }

                if hiddenCount > 0 {
                    Text("+\(hiddenCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var displayEvents: [CalendarEventDigest] {
        Array(events.sortedForWidget.prefix(compact ? 3 : 5))
    }

    private var hiddenCount: Int {
        max(0, events.count - displayEvents.count)
    }

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day).uppercased()
    }

    private var dayNumber: String {
        String(calendar.component(.day, from: day))
    }
}

private struct EventChip: View {
    var event: CalendarEventDigest
    var day: Date
    var compact: Bool

    var body: some View {
        if event.isAllDay {
            Text(event.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(compact ? 1 : 2)
                .foregroundStyle(Color(hex: event.colorHex))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: event.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(timeRange)
                    .font(.system(size: compact ? 8 : 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(event.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(compact ? 1 : 2)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(hex: event.colorHex), lineWidth: 1.5)
            )
        }
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate))-\(formatter.string(from: event.endDate))"
    }
}

private struct EmptyCalendarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar Week")
                .font(.title3.bold())

            Text(SharedCalendarData.snapshotReadStatus())
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Open the app and click Refresh Widget Events.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}

private extension Array where Element == CalendarEventDigest {
    var sortedForWidget: [CalendarEventDigest] {
        sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay {
                return lhs.isAllDay
            }

            if lhs.startDate == rhs.startDate {
                return lhs.title < rhs.title
            }

            return lhs.startDate < rhs.startDate
        }
    }
}

private extension WeekSnapshot {
    static var sample: WeekSnapshot {
        let calendar = Calendar.sundayFirstGregorian
        let weekStart = calendar.sundayFirstWeekStart(containing: Date())
        let eventDay = calendar.date(byAdding: .day, value: 2, to: weekStart) ?? Date()
        return WeekSnapshot(
            generatedAt: Date(),
            weekStart: weekStart,
            calendars: [
                CalendarDigest(id: "work", title: "Work", sourceTitle: "iCloud", colorHex: "#65C466", isSelected: true),
                CalendarDigest(id: "travel", title: "Travel", sourceTitle: "iCloud", colorHex: "#FF5E78", isSelected: true)
            ],
            events: [
                CalendarEventDigest(
                    id: "sample-1",
                    title: "Stay at WORK INN TPE",
                    calendarID: "travel",
                    calendarTitle: "Travel",
                    colorHex: "#65C466",
                    startDate: eventDay,
                    endDate: eventDay,
                    isAllDay: true
                ),
                CalendarEventDigest(
                    id: "sample-2",
                    title: "Flight to TPE",
                    calendarID: "travel",
                    calendarTitle: "Travel",
                    colorHex: "#65C466",
                    startDate: calendar.date(byAdding: .hour, value: 18, to: eventDay) ?? eventDay,
                    endDate: calendar.date(byAdding: .hour, value: 22, to: eventDay) ?? eventDay,
                    isAllDay: false
                )
            ]
        )
    }
}

@main
struct WeekCalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeekCalendarWidget()
    }
}

struct WeekCalendarWidget: Widget {
    let kind = "WeekCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekCalendarProvider()) { entry in
            WeekCalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calendar Week")
        .description("Shows the selected Apple Calendar events across the full week.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}
