import EventKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var store = CalendarStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calendar Week Widget")
                        .font(.title2.bold())
                    Text(store.statusText)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await store.requestCalendarAccess()
                        }
                    } label: {
                        Label("Grant Calendar Access", systemImage: "calendar.badge.checkmark")
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.hasCalendarAccess)

                    Button {
                        Task {
                            await store.reloadAll()
                        }
                    } label: {
                        Label("Refresh Widget Events", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.large)
                    .disabled(!store.hasCalendarAccess)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Selected Calendars")
                        .font(.title3.bold())
                    Spacer()
                    Text("\(store.selectedCalendarIDs.count) selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if store.calendars.isEmpty {
                    ContentUnavailableView(
                        "No Calendars Loaded",
                        systemImage: "calendar",
                        description: Text("Grant Calendar access, then refresh.")
                    )
                } else {
                    List(store.calendars) { calendar in
                        CalendarSelectionRow(
                            calendar: calendar,
                            isSelected: store.selectedCalendarIDs.contains(calendar.id)
                        )
                    }
                    .listStyle(.inset)
                }
            }

            Text("After you choose calendars, add the widget from macOS widget editing and pick \"Calendar Week\".")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .task {
            await store.reloadAll()
        }
    }
}

private struct CalendarSelectionRow: View {
    var calendar: CalendarDigest
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color(hex: calendar.colorHex) : Color.secondary)
                .imageScale(.large)

            Circle()
                .fill(Color(hex: calendar.colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title)
                    .foregroundStyle(.primary)

                if let sourceTitle = calendar.sourceTitle, !sourceTitle.isEmpty {
                    Text(sourceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var calendars: [CalendarDigest] = []
    @Published private(set) var selectedCalendarIDs: Set<String> = []
    @Published private(set) var statusText = "Checking Calendar permission..."

    private let eventStore = EKEventStore()

    var hasCalendarAccess: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    init() {
        selectedCalendarIDs = SharedCalendarData.loadSelectedCalendarIDs()
    }

    func requestCalendarAccess() async {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }

            statusText = granted ? "Calendar access granted." : "Calendar access was not granted."
            await reloadAll()
        } catch {
            statusText = "Calendar access failed: \(error.localizedDescription)"
        }
    }

    func reloadAll() async {
        guard hasCalendarAccess else {
            statusText = "Calendar permission is required before the widget can show Apple Calendar events."
            calendars = []
            return
        }

        reloadCalendars()
        let snapshotResult = refreshSnapshot()
        WidgetCenter.shared.reloadTimelines(ofKind: "WeekCalendarWidget")
        statusText = snapshotResult.saved
            ? "Synced with Apple Calendar and updated \(snapshotResult.eventCount) events."
            : "Calendar events loaded, but shared widget storage is not available."
    }

    func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
        } else {
            selectedCalendarIDs.insert(id)
        }

        SharedCalendarData.saveSelectedCalendarIDs(selectedCalendarIDs)
        calendars = calendars.map { calendar in
            var copy = calendar
            copy.isSelected = selectedCalendarIDs.contains(calendar.id)
            return copy
        }
        let snapshotResult = refreshSnapshot()
        WidgetCenter.shared.reloadTimelines(ofKind: "WeekCalendarWidget")
        statusText = snapshotResult.saved
            ? "Widget snapshot updated with \(snapshotResult.eventCount) events."
            : "Calendar events loaded, but shared widget storage is not available."
    }

    private func reloadCalendars() {
        let eventCalendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        selectedCalendarIDs = visibleCalendarIDs(from: eventCalendars)
        SharedCalendarData.saveSelectedCalendarIDs(selectedCalendarIDs)

        calendars = eventCalendars.map { calendar in
                CalendarDigest(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source.title,
                    colorHex: calendar.cgColor.hexString,
                    isSelected: selectedCalendarIDs.contains(calendar.calendarIdentifier)
                )
        }
    }

    private func visibleCalendarIDs(from calendars: [EKCalendar]) -> Set<String> {
        let allCalendarIDs = Set(calendars.map(\.calendarIdentifier))
        guard let disabledIDs = appleCalendarDisabledIDs() else {
            return selectedCalendarIDs.isEmpty ? allCalendarIDs : selectedCalendarIDs
        }

        return allCalendarIDs.subtracting(disabledIDs)
    }

    private func appleCalendarDisabledIDs() -> Set<String>? {
        guard let calendarDefaults = UserDefaults(suiteName: "com.apple.iCal"),
              let disabledCalendars = calendarDefaults.dictionary(forKey: "DisabledCalendars") else {
            return nil
        }

        let ids = disabledCalendars.values.flatMap { value -> [String] in
            value as? [String] ?? []
        }

        return Set(ids)
    }

    private func refreshSnapshot() -> (eventCount: Int, saved: Bool) {
        let calendar = Calendar.sundayFirstGregorian
        let currentWeekStart = calendar.sundayFirstWeekStart(containing: Date())
        let eventRangeStart = calendar.date(byAdding: .weekOfYear, value: -8, to: currentWeekStart) ?? currentWeekStart
        let eventRangeEnd = calendar.date(byAdding: .weekOfYear, value: 9, to: currentWeekStart) ?? Date()
        let selectedCalendars = eventStore.calendars(for: .event)
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }

        let predicate = eventStore.predicateForEvents(
            withStart: eventRangeStart,
            end: eventRangeEnd,
            calendars: selectedCalendars
        )

        let events = eventStore.events(matching: predicate)
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.title < rhs.title
                }
                return lhs.startDate < rhs.startDate
            }
            .map { event in
                CalendarEventDigest(
                    id: event.eventIdentifier,
                    title: event.title,
                    calendarID: event.calendar.calendarIdentifier,
                    calendarTitle: event.calendar.title,
                    colorHex: event.calendar.cgColor.hexString,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay
                )
            }

        let snapshot = WeekSnapshot(
            generatedAt: Date(),
            weekStart: currentWeekStart,
            calendars: calendars,
            events: events
        )

        let saved = SharedCalendarData.saveSnapshot(snapshot)
        return (events.count, saved)
    }
}

private extension CGColor {
    var hexString: String {
        guard let components = converted(to: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components else {
            return "#3478F6"
        }

        if components.count >= 3 {
            return .hexString(red: components[0], green: components[1], blue: components[2])
        }

        if let gray = components.first {
            return .hexString(red: gray, green: gray, blue: gray)
        }

        return "#3478F6"
    }
}
