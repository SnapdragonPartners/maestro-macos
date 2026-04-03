//
//  MenuBarView.swift
//  Maestro App Factory
//

import Combine
import Sparkle
import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    let updater: SPUUpdater
    var onOpenWebUI: () -> Void
    var onCopyPassword: () -> Void
    var onSelectDirectory: () -> Void
    var onRestart: () -> Void
    var onStop: () -> Void
    var onViewLog: () -> Void
    var onAbout: () -> Void
    var onQuit: () -> Void

    private var statusLine: String {
        switch appState.status {
        case .running:
            return "\u{1F7E2} Maestro is running"
        case .starting:
            return "\u{1F7E1} Maestro is starting..."
        case .stopping:
            return "\u{1F7E1} Maestro is stopping..."
        case .stopped:
            return "\u{1F534} Maestro is stopped"
        case .error:
            return "\u{1F534} Maestro error"
        }
    }

    var body: some View {
        Button(statusLine) {}
            .disabled(true)

        if let dir = appState.projectDirectory {
            Button("\u{1F4C2} \(dir.lastPathComponent)") {}
                .disabled(true)
        }

        Divider()

        Button("\u{1F310} Open Web UI") {
            onOpenWebUI()
        }
        .disabled(!appState.isRunning)

        Button("\u{1F4CB} Copy Password") {
            onCopyPassword()
        }
        .disabled(appState.password == nil)

        Divider()

        Button("\u{1F4C1} Select Project Directory...") {
            onSelectDirectory()
        }

        Divider()

        Button("\u{1F504} Restart Maestro") {
            onRestart()
        }
        .disabled(appState.isStarting)

        Button("\u{23F9}\u{FE0F} Stop Maestro") {
            onStop()
        }
        .disabled(!appState.isRunning)

        Divider()

        Button("\u{1F4DC} View Log...") {
            onViewLog()
        }
        .disabled(appState.projectDirectory == nil)

        Toggle("\u{1F4CA} Send Telemetry", isOn: $appState.telemetryEnabled)

        CheckForUpdatesView(updater: updater)

        Button("About Maestro") {
            onAbout()
        }

        Button("Quit") {
            onQuit()
        }
        .keyboardShortcut("q")
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var observation: Any?

    init(updater: SPUUpdater) {
        observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, change in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }
}
