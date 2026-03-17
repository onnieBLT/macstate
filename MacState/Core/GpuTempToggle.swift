import Foundation

@MainActor
final class GpuTempToggle: ObservableObject {
    static let shared = GpuTempToggle()
    static let changedNotification = Notification.Name("MacStateGpuTempToggleChanged")

    private let defaultsKey = "module_enabled_gpu_temp"

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
            name: GpuTempToggle.changedNotification,
            object: nil,
            userInfo: ["enabled": value]
        )
    }
}
