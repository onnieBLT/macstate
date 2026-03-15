import Foundation
import AppKit

struct ProcessCPUUsage {
    let pid: Int32
    let name: String
    let icon: NSImage?
    let cpuPercent: Double
    let command: String
}

final class ProcessCPUService {
    static let shared = ProcessCPUService()

    private var previousTimes: [pid_t: UInt64] = [:]
    private var previousTimestamp: TimeInterval = 0

    private init() {
        _ = sampleAllProcesses()
        previousTimestamp = ProcessInfo.processInfo.systemUptime
    }

    func topProcesses(limit: Int = 10) -> [ProcessCPUUsage] {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - previousTimestamp
        guard elapsed > 0.1 else { return [] }

        let samples = sampleAllProcesses()
        defer {
            previousTimestamp = now
            previousTimes = samples
        }

        let elapsedNs = UInt64(elapsed * 1_000_000_000)
        var lightweight: [(pid: pid_t, cpu: Double)] = []

        for (pid, totalNs) in samples {
            guard let prevNs = previousTimes[pid] else { continue }
            let delta = totalNs &- prevNs
            guard delta > 0 else { continue }
            let cpu = Double(delta) / Double(elapsedNs) * 100.0
            if cpu > 0.05 {
                lightweight.append((pid: pid, cpu: cpu))
            }
        }

        lightweight.sort { $0.cpu > $1.cpu }
        let topEntries = lightweight.prefix(limit)

        var results: [ProcessCPUUsage] = []
        results.reserveCapacity(topEntries.count)

        for entry in topEntries {
            let (name, icon, command) = resolveProcess(pid: entry.pid)
            results.append(ProcessCPUUsage(
                pid: entry.pid,
                name: name,
                icon: icon,
                cpuPercent: entry.cpu,
                command: command
            ))
        }

        return results
    }

    // MARK: - Sampling

    private func sampleAllProcesses() -> [pid_t: UInt64] {
        let pids = listAllPids()
        var result: [pid_t: UInt64] = [:]
        result.reserveCapacity(pids.count)

        for pid in pids {
            if let ns = cpuTimeNs(for: pid) {
                result[pid] = ns
            }
        }

        return result
    }

    private func listAllPids() -> [pid_t] {
        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { return [] }

        let capacity = Int(estimated) * 2
        var pids = [pid_t](repeating: 0, count: capacity)
        let bufSize = Int32(capacity * MemoryLayout<pid_t>.size)
        let actual = proc_listallpids(&pids, bufSize)
        guard actual > 0 else { return [] }

        return Array(pids.prefix(Int(actual)))
    }

    private func cpuTimeNs(for pid: pid_t) -> UInt64? {
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)
        guard ret == size else { return nil }
        return taskInfo.pti_total_user + taskInfo.pti_total_system
    }

    // MARK: - Process Resolution

    private func resolveProcess(pid: pid_t) -> (name: String, icon: NSImage?, command: String) {
        let app = NSRunningApplication(processIdentifier: pid)
        let icon = app?.icon

        if let localizedName = app?.localizedName, !localizedName.isEmpty {
            let command = processPath(pid: pid)
            return (name: localizedName, icon: icon, command: command)
        }

        let path = processPath(pid: pid)
        if !path.isEmpty {
            let lastComponent = (path as NSString).lastPathComponent
            if !lastComponent.isEmpty {
                return (name: lastComponent, icon: icon, command: path)
            }
        }

        let name = processName(pid: pid)
        return (name: name, icon: icon, command: path)
    }

    private func processPath(pid: pid_t) -> String {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let ret = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        if ret > 0 {
            return String(cString: pathBuffer)
        }
        return ""
    }

    private func processName(pid: pid_t) -> String {
        var info = proc_taskallinfo()
        let size = Int32(MemoryLayout<proc_taskallinfo>.size)
        let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size)
        if ret == size {
            return withUnsafePointer(to: info.pbsd.pbi_comm) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                    String(cString: $0)
                }
            }
        }
        return "PID \(pid)"
    }
}
