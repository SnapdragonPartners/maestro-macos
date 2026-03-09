//
//  MenuBarView.swift
//  Maestro App Factory
//

import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    var onOpenWebUI: () -> Void
    var onCopyPassword: () -> Void
    var onSelectDirectory: () -> Void
    var onRestart: () -> Void
    var onStop: () -> Void
    var onQuit: () -> Void

    private var statusLine: String {
        switch appState.status {
        case .running:
            return "\u{1F7E2} Maestro is running"
        case .starting:
            return "\u{1F7E1} Maestro is starting..."
        case .stopped:
            return "\u{1F534} Maestro is stopped"
        case .error:
            return "\u{1F534} Maestro error"
        }
    }

    var body: some View {
        Button(statusLine) {}
            .disabled(true)

        if let version = appState.maestroVersion {
            Button("\u{2139}\u{FE0F} \(version)") {}
                .disabled(true)
        }

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

        Button("Quit") {
            onQuit()
        }
        .keyboardShortcut("q")
    }
}
