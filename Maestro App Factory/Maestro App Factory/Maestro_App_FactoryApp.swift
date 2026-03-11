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
        if appState.projectDirectory == nil {
            showDirectoryPicker()
        }
        if appState.projectDirectory != nil {
            await appState.startMaestro()
        } else {
            // No directory selected — show startup window so app is always visible
            appState.appendLog("No project directory selected.")
            appState.appendLog("Use the menu bar icon (top right) to select a project, or quit.")
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

        showDirectoryPicker()

        if appState.projectDirectory != nil {
            Task {
                await appState.restartMaestro()
            }
        }
    }

    private func showDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your Maestro project directory"

        if panel.runModal() == .OK, let url = panel.url {
            appState.projectDirectory = url
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
