import AudioToolbox
import UserNotifications

@MainActor
final class MeetingAlert: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MeetingAlert()

    func prepare() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func ring(body: String) {
        AudioServicesPlaySystemSound(1013)
        let content = UNMutableNotificationContent()
        content.title = "Town Hall"
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
