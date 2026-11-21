import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no Dock icon, menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar status item and popover
        StatusItemManager.shared.setup()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        // Safety: Return all fans to system auto control when quitting
        _ = SMCClient.shared.resetAllFans()
        smc_bridge_close()
    }
}
