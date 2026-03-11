//
//  AppDelegate.swift
//  Maestro App Factory
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var onLaunch: (() -> Void)?
    var processManager: ProcessManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        onLaunch?()
    }

    func applicationWillTerminate(_ notification: Notification) {
        processManager?.stop()
    }

    /// When user clicks the dock icon, activate the app so the menu bar is discoverable
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
}
