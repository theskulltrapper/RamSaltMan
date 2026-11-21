import SwiftUI
import Combine

public enum MainTab: String, CaseIterable, Identifiable {
    case dashboard = "Overview"
    case fans = "Fans"
    case settings = "Display"
    case about = "About"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .fans: return "fanblades"
        case .settings: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

struct MainContainerView: View {
    @ObservedObject var vm = DashboardViewModel.shared
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    Text("RamSaltMan")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                // Custom Tab Switcher
                HStack(spacing: 2) {
                    ForEach(MainTab.allCases) { tab in
                        Button(action: { vm.selectedTab = tab }) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 10))
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: vm.selectedTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(vm.selectedTab == tab ? Color.secondary.opacity(0.18) : Color.clear)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))

            Divider().opacity(0.4)

            // Content Area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    switch vm.selectedTab {
                    case .dashboard:
                        VStack(spacing: 12) {
                            MemorySectionView(
                                snapshot: vm.memorySnapshot,
                                onPurge: { vm.purgeMemory() }
                            )

                            CPUSectionView(snapshot: vm.cpuSnapshot)

                            ThermalSectionView(
                                thermals: vm.thermals,
                                useFahrenheit: settings.useFahrenheit,
                                onRefresh: { vm.forceThermalRefresh() }
                            )
                        }

                    case .fans:
                        FanControlView(
                            fans: vm.fans,
                            sliderValues: vm.fanSliderValues,
                            isHelperInstalled: vm.isHelperInstalled,
                            onAuthorize: {
                                vm.installHelper()
                            },
                            onSetFanSpeed: { index, speed in
                                vm.setFanSpeed(index: index, speed: speed)
                            },
                            onSetFanAuto: { index in
                                vm.setFanAuto(index: index)
                            },
                            onResetAll: {
                                vm.resetAllFans()
                            }
                        )

                    case .settings:
                        SettingsView()

                    case .about:
                        AboutView()
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 360, height: 520)
        .onAppear {
            vm.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverWillOpen)) { _ in
            vm.refresh()
        }
    }
}
