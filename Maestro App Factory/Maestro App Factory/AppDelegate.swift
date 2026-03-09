//
//  AppDelegate.swift
//  Maestro App Factory
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var onLaunch: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        onLaunch?()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Process cleanup handled by the app state
    }
}
