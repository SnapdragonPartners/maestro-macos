//
//  DockerChecker.swift
//  Maestro App Factory
//

import AppKit
import Foundation

enum DockerStatus {
    case ready
    case notInstalled
    case notRunning
}

struct DockerChecker {
    private static let dockerPaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/usr/bin/docker"
    ]

    static func check() async -> DockerStatus {
        // Find docker binary
        guard let dockerPath = dockerPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return .notInstalled
        }

        // Check if daemon is running
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = ["info"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? .ready : .notRunning
        } catch {
            return .notRunning
        }
    }

    static func showNotInstalledAlert() {
        let alert = NSAlert()
        alert.messageText = "Docker Required"
        alert.informativeText = "Maestro requires Docker Desktop to run. Please install Docker Desktop and try again."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open Docker Website")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://www.docker.com/products/docker-desktop/")!)
        }
    }

    static func showNotRunningAlert() {
        let alert = NSAlert()
        alert.messageText = "Docker Not Running"
        alert.informativeText = "Docker Desktop is installed but not running. Please start Docker Desktop and try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Docker Desktop")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Docker.app"))
        }
    }
}
