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
}
