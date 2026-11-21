import Foundation
import Combine

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // MARK: - Menu Bar Display Options
    @Published public var showIcon: Bool {
        didSet { UserDefaults.standard.set(showIcon, forKey: "showIcon") }
    }
    @Published public var showRAMPercent: Bool {
        didSet { UserDefaults.standard.set(showRAMPercent, forKey: "showRAMPercent") }
    }
    @Published public var showRAMGigabytes: Bool {
        didSet { UserDefaults.standard.set(showRAMGigabytes, forKey: "showRAMGigabytes") }
    }
    @Published public var showCPU: Bool {
        didSet { UserDefaults.standard.set(showCPU, forKey: "showCPU") }
    }
    @Published public var showFan: Bool {
        didSet { UserDefaults.standard.set(showFan, forKey: "showFan") }
    }
    @Published public var showTemp: Bool {
        didSet { UserDefaults.standard.set(showTemp, forKey: "showTemp") }
    }

    // MARK: - Monitoring Preferences
    @Published public var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    @Published public var liveThermalMonitoring: Bool {
        didSet { UserDefaults.standard.set(liveThermalMonitoring, forKey: "liveThermalMonitoring") }
    }
    @Published public var useFahrenheit: Bool {
        didSet { UserDefaults.standard.set(useFahrenheit, forKey: "useFahrenheit") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    // MARK: - Developer Info & Redirect
    public let developerName = "Shauryaveer Singh Sapra"
    public let githubUsername = "@theskulltrapper"
    public let githubURL = URL(string: "https://github.com/theskulltrapper")!
    public let repoURL = URL(string: "https://github.com/theskulltrapper/RamSaltMan")!

    private init() {
        let defaults = UserDefaults.standard

        // Defaults if first run
        if defaults.object(forKey: "showIcon") == nil { defaults.set(true, forKey: "showIcon") }
        if defaults.object(forKey: "showRAMPercent") == nil { defaults.set(true, forKey: "showRAMPercent") }
        if defaults.object(forKey: "showRAMGigabytes") == nil { defaults.set(false, forKey: "showRAMGigabytes") }
        if defaults.object(forKey: "showCPU") == nil { defaults.set(false, forKey: "showCPU") }
        if defaults.object(forKey: "showFan") == nil { defaults.set(false, forKey: "showFan") }
        if defaults.object(forKey: "showTemp") == nil { defaults.set(false, forKey: "showTemp") }
        if defaults.object(forKey: "refreshInterval") == nil { defaults.set(2.0, forKey: "refreshInterval") }
        if defaults.object(forKey: "liveThermalMonitoring") == nil { defaults.set(false, forKey: "liveThermalMonitoring") }
        if defaults.object(forKey: "useFahrenheit") == nil { defaults.set(false, forKey: "useFahrenheit") }
        if defaults.object(forKey: "launchAtLogin") == nil { defaults.set(false, forKey: "launchAtLogin") }

        self.showIcon = defaults.bool(forKey: "showIcon")
        self.showRAMPercent = defaults.bool(forKey: "showRAMPercent")
        self.showRAMGigabytes = defaults.bool(forKey: "showRAMGigabytes")
        self.showCPU = defaults.bool(forKey: "showCPU")
        self.showFan = defaults.bool(forKey: "showFan")
        self.showTemp = defaults.bool(forKey: "showTemp")
        self.refreshInterval = defaults.double(forKey: "refreshInterval")
        self.liveThermalMonitoring = defaults.bool(forKey: "liveThermalMonitoring")
        self.useFahrenheit = defaults.bool(forKey: "useFahrenheit")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    /// Ensure at least one element is visible in the menu bar
    public func validateVisibility() {
        if !showIcon && !showRAMPercent && !showRAMGigabytes && !showCPU && !showFan && !showTemp {
            showIcon = true
        }
    }
}
