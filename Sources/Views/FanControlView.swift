import SwiftUI

struct FanControlView: View {
    let fans: [FanInfo]
    let sliderValues: [Int: Double]
    let onSetFanSpeed: (Int, Double) -> Void
    let onSetFanAuto: (Int) -> Void
    let onResetAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fan Control", systemImage: "fanblades")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Reset All to Auto", action: onResetAll)
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if fans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fanblades.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No Cooling Fans Detected")
                        .font(.system(size: 12, weight: .medium))
                    Text("This device may be passively cooled (such as MacBook Air) or running without active fans.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
            } else {
                ForEach(fans) { fan in
                    let currentVal = sliderValues[fan.index] ?? (fan.targetRPM > 0 ? fan.targetRPM : (fan.currentRPM > 0 ? fan.currentRPM : fan.minRPM))
                    FanCardView(
                        fan: fan,
                        currentValue: currentVal,
                        onSetSpeed: { speed in
                            onSetFanSpeed(fan.index, speed)
                        },
                        onSetAuto: {
                            onSetFanAuto(fan.index)
                        }
                    )
                }
            }

            // Safety Warning Card
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thermal Safeguard Active")
                        .font(.system(size: 11, weight: .semibold))
                    Text("If die temperatures reach 85°C (185°F), RamSaltMan automatically overrides manual mode and maximizes fan speed to protect your hardware.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
        }
    }
}

struct FanCardView: View {
    let fan: FanInfo
    let currentValue: Double
    let onSetSpeed: (Double) -> Void
    let onSetAuto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(fan.name)
                        .font(.system(size: 12, weight: .semibold))
                    Text("Min: \(Int(fan.minRPM)) • Max: \(Int(fan.maxRPM)) RPM")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Mode indicator
                Text(fan.isManual ? "Manual" : "Auto")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(fan.isManual ? Color.orange.opacity(0.18) : Color.green.opacity(0.18))
                    .foregroundColor(fan.isManual ? .orange : .green)
                    .cornerRadius(4)
                Text(fan.formattedRPM)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }

            // Slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { currentValue },
                        set: { onSetSpeed($0) }
                    ),
                    in: max(1000, fan.minRPM)...max(fan.minRPM + 500, fan.maxRPM),
                    step: 50
                ) {
                    Text("Speed")
                }
                HStack {
                    Text("\(Int(currentValue)) RPM Target")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Apply Speed") {
                        onSetSpeed(currentValue)
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }

            // Preset Buttons
            HStack(spacing: 6) {
                Button("Auto") {
                    onSetAuto()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Quiet") {
                    let quietRPM = max(fan.minRPM, 1800.0)
                    onSetSpeed(quietRPM)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Balanced") {
                    let midRPM = (fan.minRPM + fan.maxRPM) / 2.0
                    onSetSpeed(midRPM)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Max") {
                    onSetSpeed(fan.maxRPM)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}
