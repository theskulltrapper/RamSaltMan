import Foundation
import Darwin

public struct CPUSnapshot: Equatable {
    public let totalUsage: Double
    public let userUsage: Double
    public let systemUsage: Double
    public let idleUsage: Double
    public let coreUsages: [Double]
    public let totalCores: Int
    public let performanceCores: Int
    public let efficiencyCores: Int

    public var formattedTotal: String {
        return String(format: "%.1f%%", totalUsage)
    }

    public var formattedUser: String {
        return String(format: "%.1f%%", userUsage)
    }

    public var formattedSystem: String {
        return String(format: "%.1f%%", systemUsage)
    }

    public static let zero = CPUSnapshot(
        totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100.0,
        coreUsages: [], totalCores: 1, performanceCores: 1, efficiencyCores: 0
    )
}

public final class CPUMonitor {
    public static let shared = CPUMonitor()

    private let hostPort = mach_host_self()
    private var previousLoadInfo: processor_info_array_t?
    private var previousLoadInfoCount: mach_msg_type_number_t = 0
    private var previousCpuCount: natural_t = 0

    public let totalCores: Int
    public let performanceCores: Int
    public let efficiencyCores: Int

    private init() {
        var ncpu: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.logicalcpu", &ncpu, &size, nil, 0) != 0 {
            ncpu = Int32(ProcessInfo.processInfo.activeProcessorCount)
        }
        totalCores = Int(ncpu)

        var pCores: Int32 = 0
        var pSize = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.logicalcpu", &pCores, &pSize, nil, 0) == 0 {
            performanceCores = Int(pCores)
        } else {
            performanceCores = totalCores
        }

        var eCores: Int32 = 0
        var eSize = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel1.logicalcpu", &eCores, &eSize, nil, 0) == 0 {
            efficiencyCores = Int(eCores)
        } else {
            efficiencyCores = max(0, totalCores - performanceCores)
        }
    }

    deinit {
        if let prev = previousLoadInfo {
            let prevSize = vm_size_t(previousLoadInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prev)), prevSize)
        }
    }

    public func sample() -> CPUSnapshot {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &infoArray,
            &infoCount
        )

        guard kr == KERN_SUCCESS, let currentInfo = infoArray else {
            return .zero
        }

        guard let prevInfo = previousLoadInfo, previousCpuCount == cpuCount else {
            previousLoadInfo = currentInfo
            previousLoadInfoCount = infoCount
            previousCpuCount = cpuCount
            return .zero
        }

        var totalUser: Int64 = 0
        var totalSystem: Int64 = 0
        var totalIdle: Int64 = 0
        var totalNice: Int64 = 0
        var corePercentages: [Double] = []

        let stride = Int(CPU_STATE_MAX)

        for i in 0..<Int(cpuCount) {
            let base = i * stride
            let user = Int64(currentInfo[base + Int(CPU_STATE_USER)] - prevInfo[base + Int(CPU_STATE_USER)])
            let system = Int64(currentInfo[base + Int(CPU_STATE_SYSTEM)] - prevInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = Int64(currentInfo[base + Int(CPU_STATE_IDLE)] - prevInfo[base + Int(CPU_STATE_IDLE)])
            let nice = Int64(currentInfo[base + Int(CPU_STATE_NICE)] - prevInfo[base + Int(CPU_STATE_NICE)])

            let coreTotal = user + system + idle + nice
            let coreUsage = coreTotal > 0 ? (Double(user + system + nice) / Double(coreTotal)) * 100.0 : 0.0
            corePercentages.append(min(100.0, max(0.0, coreUsage)))

            totalUser += user
            totalSystem += system
            totalIdle += idle
            totalNice += nice
        }

        // Clean up previous buffer and update reference
        let prevSize = vm_size_t(previousLoadInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prevInfo)), prevSize)

        previousLoadInfo = currentInfo
        previousLoadInfoCount = infoCount
        previousCpuCount = cpuCount

        let grandTotal = totalUser + totalSystem + totalIdle + totalNice
        guard grandTotal > 0 else {
            return .zero
        }

        let userPct = (Double(totalUser + totalNice) / Double(grandTotal)) * 100.0
        let sysPct = (Double(totalSystem) / Double(grandTotal)) * 100.0
        let idlePct = (Double(totalIdle) / Double(grandTotal)) * 100.0
        let totalPct = min(100.0, max(0.0, userPct + sysPct))

        return CPUSnapshot(
            totalUsage: totalPct,
            userUsage: userPct,
            systemUsage: sysPct,
            idleUsage: idlePct,
            coreUsages: corePercentages,
            totalCores: totalCores,
            performanceCores: performanceCores,
            efficiencyCores: efficiencyCores
        )
    }
}
