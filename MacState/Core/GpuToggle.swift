import Foundation

@MainActor
final class GpuToggle: ObservableObject {
    static let shared = GpuToggle()
    static let changedNotification = Notification.Name("MacStateGpuToggleChanged")

    private let defaultsKey = "module_enabled_gpu_usage"

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
            name: GpuToggle.changedNotification,
            object: nil,
            userInfo: ["enabled": value]
        )
    }
}
