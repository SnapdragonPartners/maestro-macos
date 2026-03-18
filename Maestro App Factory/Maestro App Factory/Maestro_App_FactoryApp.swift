//
//  Maestro_App_FactoryApp.swift
//  Maestro App Factory
//

import Sparkle
import SwiftUI

@main
struct Maestro_App_FactoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        MenuBarExtra("Maestro", image: menuBarIcon) {
            MenuBarView(
                appState: appState,
                updater: updaterController.updater,
                onOpenWebUI: openWebUI,
                onCopyPassword: copyPassword,
                onSelectDirectory: selectDirectory,
                onRestart: restartMaestro,
                onStop: stopMaestro,
                onViewLog: showLogViewer,
                onAbout: showAbout,
                onQuit: quitApp
            )
        }
    }

    init() {
        // Give the delegate a reference to ProcessManager for cleanup on quit
        DispatchQueue.main.async { [self] in
            self.appDelegate.processManager = self.appState.processManager
        }

        // Schedule first launch after a brief delay to let SwiftUI set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            Task { @MainActor in
                await self.firstLaunch()
            }
        }
    }

    private var menuBarIcon: String {
        appState.isRunning ? "MenuBarIcon" : "MenuBarIconOff"
    }

    // MARK: - First Launch

    @MainActor
    private func firstLaunch() async {
        if appState.needsOnboarding {
            await withCheckedContinuation { continuation in
                appState.showWelcome {
                    continuation.resume()
                }
            }
        }

        if appState.projectDirectory == nil {
            appState.showDirectoryPicker()
        }
        if appState.projectDirectory != nil {
            await appState.startMaestro()
        } else {
            // No directory selected — show startup window so app is always visible
            appState.appendLog("No project directory selected.")
            appState.appendLog("Select a project directory to get started, or quit.")
            appState.showStartupWindow()
        }
    }

    // MARK: - Actions

    private func openWebUI() {
        guard let url = appState.webUIURL else { return }
        NSWorkspace.shared.open(url)
        appState.hasOpenedWebUI = true
    }

    private func copyPassword() {
        guard let password = appState.password else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(password, forType: .string)
    }

    private func selectDirectory() {
        if appState.isRunning {
            let alert = NSAlert()
            alert.messageText = "Change Project Directory?"
            alert.informativeText = "Changing projects will stop the current Maestro session."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }

        appState.showDirectoryPicker()

        if appState.projectDirectory != nil {
            Task {
                await appState.restartMaestro()
            }
        }
    }

    private func restartMaestro() {
        Task {
            await appState.restartMaestro()
        }
    }

    private func stopMaestro() {
        appState.stopMaestro()
    }

    private func showLogViewer() {
        appState.showLogViewer()
    }

    private func showAbout() {
        let aboutView = AboutView(
            maestroVersion: appState.maestroVersion,
            controlPanelBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 440)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Maestro"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func quitApp() {
        appState.stopMaestro()
        NSApplication.shared.terminate(nil)
    }
}
