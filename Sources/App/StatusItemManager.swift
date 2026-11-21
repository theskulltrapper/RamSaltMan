import AppKit
import SwiftUI

public final class StatusItemManager: NSObject {
    public static let shared = StatusItemManager()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var timer: Timer?

    private let memoryMonitor = MemoryMonitor.shared
    private let cpuMonitor = CPUMonitor.shared
    private let smcClient = SMCClient.shared
    private let thermalMonitor = ThermalMonitor.shared
    private let settings = AppSettings.shared

    private var isPopoverOpen: Bool {
        return popover?.isShown ?? false
    }

    public override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.animates = true

        let contentView = MainContainerView()
        popover.contentViewController = NSHostingController(rootView: contentView)

        startTimer()
        updateMenuBar()
    }

    public func restartTimer() {
        timer?.invalidate()
        timer = nil
        startTimer()
    }

    private func startTimer() {
        let interval = max(1.0, settings.refreshInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        let currentEvent = NSApp.currentEvent
        if currentEvent?.type == .rightMouseUp {
            showContextMenu(button)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Trigger an immediate sample when opening
            NotificationCenter.default.post(name: .popoverWillOpen, object: nil)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(_ button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "RamSaltMan", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "By Shauryaveer Singh Sapra", action: #selector(openDeveloperURL), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openPopoverFromMenu), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Purge Inactive Memory", action: #selector(purgeMemoryAction), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Reset Fans to Auto", action: #selector(resetFansAction), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit RamSaltMan", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openDeveloperURL() {
        NSWorkspace.shared.open(settings.githubURL)
    }

    @objc private func openPopoverFromMenu() {
        if let button = statusItem.button, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func purgeMemoryAction() {
        memoryMonitor.purgeMemory()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateMenuBar()
        }
    }

    @objc private func resetFansAction() {
        _ = smcClient.resetAllFans()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    public func updateMenuBar() {
        guard let button = statusItem.button else { return }

        // Adaptive polling: only sample metrics that are active
        let needRAM = settings.showRAMPercent || settings.showRAMGigabytes || isPopoverOpen
        let needCPU = settings.showCPU || isPopoverOpen
        let needFan = settings.showFan || isPopoverOpen
        let needTemp = settings.showTemp || (isPopoverOpen && settings.liveThermalMonitoring)

        var parts: [String] = []

        // Icon
        if settings.showIcon {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let img = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "RamSaltMan")?.withSymbolConfiguration(config) {
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageLeft
            }
        } else {
            button.image = nil
        }

        // RAM
        if needRAM {
            let mem = memoryMonitor.sample()
            if settings.showRAMPercent {
                parts.append(String(format: "%.0f%%", mem.usagePercentage))
            }
            if settings.showRAMGigabytes {
                parts.append(mem.usedGBString)
            }
        }

        // CPU
        if needCPU {
            let cpu = cpuMonitor.sample()
            if settings.showCPU {
                parts.append(String(format: "CPU %.0f%%", cpu.totalUsage))
            }
        }

        // Fan
        if needFan {
            let fans = smcClient.getAllFans()
            if settings.showFan {
                if let first = fans.first, first.currentRPM > 0 {
                    parts.append(String(format: "%.0f RPM", first.currentRPM))
                } else if !fans.isEmpty {
                    parts.append("Fan Off")
                }
            }
        }

        // Temp
        if needTemp {
            let thermals = thermalMonitor.sample(forceLive: false, liveAllowed: true)
            if settings.showTemp && thermals.hasSensors {
                parts.append(ThermalMonitor.formatTemp(thermals.cpuTemp, useFahrenheit: settings.useFahrenheit))
            }
        }

        if parts.isEmpty {
            button.title = ""
            if !settings.showIcon {
                // Ensure at least an indicator
                button.title = "RAM"
            }
        } else {
            button.title = parts.joined(separator: "  ")
        }
    }
}

extension Notification.Name {
    static let popoverWillOpen = Notification.Name("RamSaltMan.popoverWillOpen")
}
