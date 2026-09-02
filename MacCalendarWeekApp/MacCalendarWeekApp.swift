import AppKit
import SwiftUI

@main
struct MacCalendarWeekApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
                .onOpenURL { url in
                    guard url.scheme == SharedCalendarData.urlScheme, url.host == "open-calendar" else {
                        return
                    }

                    CalendarLauncher.openCalendar()
                }
        }
    }
}

private enum CalendarLauncher {
    static func openCalendar() {
        let workspace = NSWorkspace.shared

        if let calendarURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            workspace.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        let fallbackURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        workspace.openApplication(at: fallbackURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
