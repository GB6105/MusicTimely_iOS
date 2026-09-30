import Foundation
import UserNotifications

/// 알림 포트 (명세서 §9.4). 모듈이 유일한 OS 알림 발송 주체다.
protocol NotificationScheduling {
    func requestAuthorizationIfNeeded() async -> Bool
    func authorizationDenied() async -> Bool
    /// 이전 키를 모두 지우고, 목표 알림이 필요하면 하나만 예약한다 (§7.2).
    func reconcile(targetKey: String?, fireInMs: Int64?) async
    func cancelAll() async
}

final class UserNotificationScheduler: NotificationScheduling {
    static let prefix = "mt.target."
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return settings.authorizationStatus == .authorized }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    func reconcile(targetKey: String?, fireInMs: Int64?) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        // 같은 키도 지우고 다시 넣어(upsert) 복귀 시점의 남은 시간으로 맞춘다 (§5.2, §7.2).
        if !pending.isEmpty { center.removePendingNotificationRequests(withIdentifiers: pending) }
        guard let targetKey, let fireInMs, fireInMs > 0 else { return }
        let wanted = Self.prefix + targetKey

        let content = UNMutableNotificationContent()
        // 작업 제목·곡명·메모는 잠금 화면에 넣지 않는다 (§7.1).
        content.body = String(localized: "정한 시간이 지났어요.")
        content.sound = nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(fireInMs) / 1_000), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: wanted, content: content, trigger: trigger))
    }

    func cancelAll() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter {
            $0.hasPrefix(Self.prefix)
        }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }
}
