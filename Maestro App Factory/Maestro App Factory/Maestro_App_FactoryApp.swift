//
//  Maestro_App_FactoryApp.swift
//  Maestro App Factory
//

import SwiftUI

@main
struct Maestro_App_FactoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Maestro", systemImage: menuBarIcon) {
            MenuBarView(
                appState: appState,
                onOpenWebUI: openWebUI,
                onCopyPassword: copyPassword,
                onSelectDirectory: selectDirectory,
                onRestart: restartMaestro,
                onStop: stopMaestro,
                onQuit: quitApp
            )
        }
        .onChange(of: appDelegate.onLaunch == nil) {
            // Trigger startup once the app delegate is wired up
        }
    }

    init() {
        // Schedule first launch after a brief delay to let SwiftUI set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            Task { @MainActor in
                await self.firstLaunch()
            }
        }
    }

    private var menuBarIcon: String {
        switch appState.status {
        case .running:
            return "circle.fill"
        case .starting:
            return "circle.dotted"
        case .stopped:
            return "circle"
        case .error:
            return "exclamationmark.circle"
        }
    }

    // MARK: - First Launch

    @MainActor
    private func firstLaunch() async {
        if appState.projectDirectory == nil {
            showDirectoryPicker()
        }
        if appState.projectDirectory != nil {
            await appState.startMaestro()
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

    private func quitApp() {
        appState.stopMaestro()
        NSApplication.shared.terminate(nil)
    }
}
