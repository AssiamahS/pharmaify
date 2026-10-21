import Foundation
import UserNotifications

final class ForegroundBanner: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

enum Notifier {
    static let delegate = ForegroundBanner()

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Tells the customer their refill moved. Local only, so it fires on the device that advanced the order.
    static func orderUpdated(_ order: RxOrder) {
        let content = UNMutableNotificationContent()
        let store = order.pharmacy?.name ?? "Your pharmacy"
        switch order.status {
        case .ready:
            content.title = "Ready for pickup"
            content.body = "\(order.medicationName) is ready at \(store)."
        case .filling:
            content.title = "Being filled"
            content.body = "\(store) is filling \(order.medicationName)."
        case .received:
            content.title = "Request received"
            content.body = "\(store) got your request for \(order.medicationName)."
        default:
            return
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func sync(_ reminder: DoseReminder) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.notificationID])
        guard reminder.isOn else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time for \(reminder.medicationName)"
        content.body = reminder.dosage.isEmpty ? "Take your dose." : "Take \(reminder.dosage)."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = reminder.hour
        comps.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: reminder.notificationID, content: content, trigger: trigger))
    }

    static func cancel(_ reminder: DoseReminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.notificationID])
    }
}
