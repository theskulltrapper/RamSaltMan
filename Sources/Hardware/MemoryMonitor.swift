import Foundation
import Darwin

public enum MemoryPressureLevel: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"

    public var badgeColorHex: String {
        switch self {
        case .normal: return "#34C759"    // Apple System Green
        case .warning: return "#FF9F0A"   // Apple System Orange
        case .critical: return "#FF3B30"  // Apple System Red
        }
    }
}

public struct MemorySnapshot: Equatable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let swapUsedBytes: UInt64
    public let swapTotalBytes: UInt64
    public let pressure: MemoryPressureLevel

    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }

    public var totalGBString: String {
        return String(format: "%.1f GB", Double(totalBytes) / 1_073_741_824.0)
    }

    public var usedGBString: String {
        return String(format: "%.1f GB", Double(usedBytes) / 1_073_741_824.0)
    }

    public var freeGBString: String {
        return String(format: "%.1f GB", Double(freeBytes) / 1_073_741_824.0)
    }

    public var activeGBString: String {
        return String(format: "%.1f GB", Double(activeBytes) / 1_073_741_824.0)
    }

    public var inactiveGBString: String {
        return String(format: "%.1f GB", Double(inactiveBytes) / 1_073_741_824.0)
    }

    public var wiredGBString: String {
        return String(format: "%.1f GB", Double(wiredBytes) / 1_073_741_824.0)
    }

    public var compressedGBString: String {
        return String(format: "%.1f GB", Double(compressedBytes) / 1_073_741_824.0)
    }

    public var swapUsedGBString: String {
        return String(format: "%.1f GB", Double(swapUsedBytes) / 1_073_741_824.0)
    }

    public static let zero = MemorySnapshot(
        totalBytes: 0, usedBytes: 0, freeBytes: 0, activeBytes: 0,
        inactiveBytes: 0, wiredBytes: 0, compressedBytes: 0,
        swapUsedBytes: 0, swapTotalBytes: 0, pressure: .normal
    )
}

public final class MemoryMonitor {
    public static let shared = MemoryMonitor()

    private let hostPort = mach_host_self()
    private let totalPhysicalMemory: UInt64

    private init() {
        totalPhysicalMemory = ProcessInfo.processInfo.physicalMemory
    }

    public func sample() -> MemorySnapshot {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard kr == KERN_SUCCESS else {
            return .zero
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let free = UInt64(vmStats.free_count) * pageSize

        // Mach VM formula for active used memory: App + Wired + Compressed
        let used = active + wired + compressed

        // Swap usage via sysctl
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let swapKr = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        let swapUsed = (swapKr == 0) ? UInt64(swapUsage.xsu_used) : 0
        let swapTotal = (swapKr == 0) ? UInt64(swapUsage.xsu_total) : 0

        // Determine Memory Pressure
        let pressure: MemoryPressureLevel
        let freeRatio = totalPhysicalMemory > 0 ? Double(free + inactive) / Double(totalPhysicalMemory) : 0.5
        if freeRatio < 0.08 || swapUsed > 2_147_483_648 { // Under 8% free/inactive or > 2GB swap
            pressure = .critical
        } else if freeRatio < 0.20 || swapUsed > 524_288_000 { // Under 20% free/inactive or > 500MB swap
            pressure = .warning
        } else {
            pressure = .normal
        }

        return MemorySnapshot(
            totalBytes: totalPhysicalMemory,
            usedBytes: min(used, totalPhysicalMemory),
            freeBytes: free,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal,
            pressure: pressure
        )
    }

    /// Trigger macOS virtual memory cleanup
    public func purgeMemory() {
        // macOS POSIX memory advice or purge utility if permitted
        DispatchQueue.global(qos: .utility).async { [weak self] in
            _ = self?.runCommand("/usr/bin/purge")
        }
    }

    private func runCommand(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = command
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }
}
