import SwiftUI

struct AboutView: View {
    let settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // App Header
            VStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)

                Text("RamSaltMan")
                    .font(.system(size: 16, weight: .bold))

                Text("Version 1.0.0 (Open Source)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            // Developer Card
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created by")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(settings.developerName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(settings.githubUsername)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Button(action: {
                        NSWorkspace.shared.open(settings.githubURL)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("GitHub Profile")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Divider().opacity(0.3)

                HStack {
                    Text("Source Code Repository")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        NSWorkspace.shared.open(settings.repoURL)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("View on GitHub")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            // Security & Privacy Card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    Text("Security & Privacy Guarantee")
                        .font(.system(size: 11, weight: .semibold))
                }

                Text("• Zero network access: RamSaltMan has no internet entitlements and cannot send or receive network data.\n• Zero personal disk access: Does not read user documents or storage.\n• 100% open-source: Auditable C & Swift codebase under the MIT License.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.06)))

            Spacer()

            // Quit Button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit RamSaltMan")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
