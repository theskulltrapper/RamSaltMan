import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Menu Bar Display Customization
            VStack(alignment: .leading, spacing: 8) {
                Label("Menu Bar Display Elements", systemImage: "menubar.rectangle")
                    .font(.system(size: 13, weight: .semibold))

                Text("Choose exactly what metrics appear in your macOS menu bar.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    Toggle("Show Status Bar Icon", isOn: $settings.showIcon)
                    Toggle("Show RAM Percentage (%)", isOn: $settings.showRAMPercent)
                    Toggle("Show RAM Used (GB)", isOn: $settings.showRAMGigabytes)
                    Toggle("Show CPU Load (%)", isOn: $settings.showCPU)
                    Toggle("Show Fan Speed (RPM)", isOn: $settings.showFan)
                    Toggle("Show Temperature", isOn: $settings.showTemp)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .onChange(of: settings.showIcon) { settings.validateVisibility() }
                .onChange(of: settings.showRAMPercent) { settings.validateVisibility() }
                .onChange(of: settings.showRAMGigabytes) { settings.validateVisibility() }
                .onChange(of: settings.showCPU) { settings.validateVisibility() }
                .onChange(of: settings.showFan) { settings.validateVisibility() }
                .onChange(of: settings.showTemp) { settings.validateVisibility() }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            // Resource Efficiency Tuning
            VStack(alignment: .leading, spacing: 8) {
                Label("Resource Efficiency & Telemetry", systemImage: "gauge.with.needle")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Update Frequency:")
                            .font(.system(size: 11))
                        Spacer()
                        Picker("", selection: $settings.refreshInterval) {
                            Text("1.0s (Fast)").tag(1.0)
                            Text("2.0s (Balanced)").tag(2.0)
                            Text("3.0s (Low CPU)").tag(3.0)
                            Text("5.0s (Ultra Lite)").tag(5.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .onChange(of: settings.refreshInterval) {
                            StatusItemManager.shared.restartTimer()
                        }
                    }

                    Divider().opacity(0.3)

                    Toggle("Continuous Live Temperature Telemetry", isOn: $settings.liveThermalMonitoring)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                    Text("When disabled, temperatures update on-demand when the popover opens, keeping idle background CPU virtually at 0.0%.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Divider().opacity(0.3)

                    Toggle("Use Fahrenheit (°F)", isOn: $settings.useFahrenheit)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
        }
    }
}
