import Foundation

@MainActor
final class CpuToggle: ObservableObject {
    static let shared = CpuToggle()
    static let changedNotification = Notification.Name("MacStateCpuToggleChanged")

    private let defaultsKey = "module_enabled_cpu_usage"

    @Published var enabled: Bool

    private init() {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            enabled = true
        } else {
            enabled = UserDefaults.standard.bool(forKey: defaultsKey)
        }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: defaultsKey)
        NotificationCenter.default.post(
            name: CpuToggle.changedNotification,
            object: nil,
            userInfo: ["enabled": value]
        )
    }
}
