import SwiftUI

struct MetricRow: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

struct MemorySectionView: View {
    let snapshot: MemorySnapshot
    let onPurge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                // Pressure Pill
                Text(snapshot.pressure.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: snapshot.pressure.badgeColorHex).opacity(0.18))
                    .foregroundColor(Color(hex: snapshot.pressure.badgeColorHex))
                    .cornerRadius(4)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(0, min(geo.size.width * CGFloat(snapshot.usagePercentage / 100.0), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(String(format: "%.1f%% Used", snapshot.usagePercentage))
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(snapshot.usedGBString) / \(snapshot.totalGBString)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Divider().opacity(0.4)

            VStack(spacing: 5) {
                MetricRow(title: "App Memory", value: snapshot.activeGBString)
                MetricRow(title: "Wired Memory", value: snapshot.wiredGBString)
                MetricRow(title: "Compressed", value: snapshot.compressedGBString)
                MetricRow(title: "Free", value: snapshot.freeGBString, color: .green)
                if snapshot.swapUsedBytes > 0 {
                    MetricRow(title: "Swap Used", value: snapshot.swapUsedGBString, color: .orange)
                }
            }

            Button(action: onPurge) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Purge Inactive Memory")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}

struct CPUSectionView: View {
    let snapshot: CPUSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Processor", systemImage: "cpu")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(snapshot.totalCores) Cores (\(snapshot.performanceCores)P + \(snapshot.efficiencyCores)E)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(0, min(geo.size.width * CGFloat(snapshot.totalUsage / 100.0), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(snapshot.formattedTotal)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("User: \(snapshot.formattedUser) | System: \(snapshot.formattedSystem)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if !snapshot.coreUsages.isEmpty {
                // Mini Core Bar visualizer
                HStack(spacing: 3) {
                    ForEach(0..<min(16, snapshot.coreUsages.count), id: \.self) { i in
                        VStack(spacing: 2) {
                            GeometryReader { g in
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(snapshot.coreUsages[i] > 80 ? Color.red : (snapshot.coreUsages[i] > 50 ? Color.orange : Color.blue))
                                        .frame(height: max(2, g.size.height * CGFloat(snapshot.coreUsages[i] / 100.0)))
                                }
                            }
                            .frame(height: 18)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}

struct ThermalSectionView: View {
    let thermals: ThermalState
    let useFahrenheit: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Thermals", systemImage: "thermometer.medium")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(thermals.statusDescription)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(thermals.maxTemp > 80 ? .red : (thermals.maxTemp > 65 ? .orange : .green))
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Refresh thermal sensors")
            }

            if thermals.hasSensors {
                HStack(spacing: 8) {
                    ThermalTile(title: "CPU Die", temp: thermals.cpuTemp, fahrenheit: useFahrenheit)
                    ThermalTile(title: "GPU", temp: thermals.gpuTemp, fahrenheit: useFahrenheit)
                    ThermalTile(title: "SoC / PMU", temp: thermals.socTemp, fahrenheit: useFahrenheit)
                    ThermalTile(title: "Battery", temp: thermals.batteryTemp, fahrenheit: useFahrenheit)
                }
            } else {
                HStack {
                    Text("Thermal telemetry is on-demand or initializing...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Read Sensors", action: onRefresh)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}

struct ThermalTile: View {
    let title: String
    let temp: Double
    let fahrenheit: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(.secondary)
            Text(ThermalMonitor.formatTemp(temp, useFahrenheit: fahrenheit))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(temp > 80 ? .red : (temp > 65 ? .orange : .primary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
