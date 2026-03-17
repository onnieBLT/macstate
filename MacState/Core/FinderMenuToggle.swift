import Foundation

@MainActor
final class FinderMenuToggle: ObservableObject {
    static let shared = FinderMenuToggle()
    static let changedNotification = Notification.Name("MacStateFinderMenuToggleChanged")

    private let defaultsKey = "module_enabled_finder_menu"

    @Published var enabled: Bool

    private init() {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            enabled = false
            UserDefaults.standard.set(false, forKey: defaultsKey)
        } else {
            enabled = UserDefaults.standard.bool(forKey: defaultsKey)
            if enabled {
                Self.activateExtensionDeferred()
            }
        }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: defaultsKey)
        NotificationCenter.default.post(
            name: FinderMenuToggle.changedNotification,
            object: nil,
            userInfo: ["enabled": value]
        )
        Self.activateExtension(value)
    }

    private static func activateExtensionDeferred() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
            activateExtension(true)
        }
    }

    private static func activateExtension(_ enable: Bool) {
        let bundleID = "com.snail007.macstate.FinderMenu"
        if enable {
            if let appexURL = Bundle.main.builtInPlugInsURL?
                .appendingPathComponent("FinderMenu.appex") {
                let register = Process()
                register.launchPath = "/usr/bin/pluginkit"
                register.arguments = ["-a", appexURL.path]
                try? register.run()
                register.waitUntilExit()
            }
            let on = Process()
            on.launchPath = "/usr/bin/pluginkit"
            on.arguments = ["-e", "use", "-i", bundleID]
            try? on.run()
        } else {
            let task = Process()
            task.launchPath = "/usr/bin/pluginkit"
            task.arguments = ["-e", "ignore", "-i", bundleID]
            try? task.run()
        }
    }
}
