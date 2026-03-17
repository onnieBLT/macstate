import Foundation
import AppKit

struct EnergyProcess {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
    let energyImpact: Double
}

final class EnergyService {
    static let shared = EnergyService()

    private typealias GetTopCoalitions = @convention(c) (Int, Int) -> Unmanaged<NSDictionary>
    private let getTopCoalitions: GetTopCoalitions?

    private init() {
        var fn: GetTopCoalitions? = nil
        if let handle = dlopen("/usr/lib/libsystemstats.dylib", RTLD_LAZY) {
            if let ptr = dlsym(handle, "systemstats_get_top_coalitions") {
                fn = unsafeBitCast(ptr, to: GetTopCoalitions.self)
            }
            dlclose(handle)
        }
        getTopCoalitions = fn
    }

    func topProcesses(limit: Int = 3, duration: Int = 3) -> [EnergyProcess] {
        guard let fn = getTopCoalitions else { return [] }

        let dict = fn(duration, 10000).takeUnretainedValue() as? [String: Any]
        guard let bundleIDs = dict?["bundle_identifiers"] as? [String],
              let impacts = dict?["energy_impacts"] as? [Double] else {
            return []
        }

        let count = min(bundleIDs.count, impacts.count)
        guard count > 0 else { return [] }

        struct Entry {
            let bundleID: String
            let impact: Double
        }

        var entries: [Entry] = []
        entries.reserveCapacity(count)

        for i in 0..<count {
            let impact = impacts[i]
            guard impact > 0 else { continue }
            let bid = bundleIDs[i]
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) != nil else { continue }
            entries.append(Entry(bundleID: bid, impact: impact))
        }

        entries.sort { $0.impact > $1.impact }

        var results: [EnergyProcess] = []
        results.reserveCapacity(min(limit, entries.count))

        for entry in entries.prefix(limit) {
            let (name, icon) = resolveApp(bundleIdentifier: entry.bundleID)
            results.append(EnergyProcess(
                bundleIdentifier: entry.bundleID,
                name: name,
                icon: icon,
                energyImpact: entry.impact
            ))
        }

        return results
    }

    // MARK: - App Resolution

    private func resolveApp(bundleIdentifier: String) -> (name: String, icon: NSImage?) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            let fallback = bundleIdentifier.split(separator: ".").last.map(String.init) ?? bundleIdentifier
            return (fallback, nil)
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)

        if let bundle = Bundle(url: url) {
            let displayName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
            if let name = displayName, !name.isEmpty {
                return (name, icon)
            }
        }

        let fileName = url.deletingPathExtension().lastPathComponent
        return (fileName, icon)
    }
}
