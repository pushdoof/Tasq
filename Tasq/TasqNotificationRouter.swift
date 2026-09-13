import Foundation
import UserNotifications
internal import Combine

/// One delegate for the entire app, including notifications opened from a cold launch.
final class TasqNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = TasqNotificationRouter()
    @Published var requestedChartID: UUID?
    var startsRoutine = false

    static func identifier(chartID: UUID, kind: String) -> String {
        "routine-\(chartID.uuidString)-\(kind)"
    }

    static func removeNotifications(for chartID: UUID) {
        let center = UNUserNotificationCenter.current()
        let prefix = "routine-\(chartID.uuidString)-"
        center.getPendingNotificationRequests { requests in
            center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(prefix) })
        }
        center.getDeliveredNotifications { notifications in
            center.removeDeliveredNotifications(withIdentifiers: notifications.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) })
        }
    }

    static func scheduleAlarm(for chart: Chart) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(chartID: chart.id, kind: "alarm")])
        guard chart.alarmEnabled,
              let hour = chart.alarmHour,
              let minute = chart.alarmMinute else { return }
        var h = hour
        if !chart.alarmIsAM && h != 12 { h += 12 }
        if chart.alarmIsAM && h == 12 { h = 0 }
        var components = DateComponents()
        components.hour = h
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = "Tasq"
        content.userInfo = ["chartID": chart.id.uuidString, "kind": "alarm"]
        content.body = "Time to start \(chart.name)!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_loop.caf"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier(chartID: chart.id, kind: "alarm"), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let id = info["chartID"] as? String, let chartID = UUID(uuidString: id) {
            DispatchQueue.main.async {
                self.startsRoutine = info["kind"] as? String == "alarm"
                self.requestedChartID = chartID
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
