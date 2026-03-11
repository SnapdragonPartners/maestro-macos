//
//  AppState.swift
//  Maestro App Factory
//

import Foundation
import SwiftUI

enum MaestroStatus: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error(String)
}

@Observable
class AppState {
    var status: MaestroStatus = .stopped
    var projectDirectory: URL? {
        didSet {
            if let url = projectDirectory {
                UserDefaults.standard.set(url.path, forKey: "projectDirectory")
            }
        }
    }
    var port: Int = 8080
    var sessionToken: String?
    var password: String?
    var maestroVersion: String?

    let processManager = ProcessManager()

    var hasOpenedWebUI = false
    var startupLog: [String] = []
    private var startupWindow: NSWindow?

    var webUIURL: URL? {
        if hasOpenedWebUI {
            return URL(string: "http://localhost:\(port)/")
        }
        guard let token = sessionToken else { return nil }
        return URL(string: "http://localhost:\(port)/auth/session?token=\(token)")
    }

    var isRunning: Bool { status == .running }
    var isStarting: Bool { status == .starting }

    init() {
        if let path = UserDefaults.standard.string(forKey: "projectDirectory") {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                self.projectDirectory = url
            }
        }

        processManager.onTermination = { [weak self] reason, status in
            guard let self else { return }
            if self.status == .running {
                // Unexpected termination
                self.appendLog("Maestro exited unexpectedly (code \(status))")
                self.status = .error("Maestro exited unexpectedly (code \(status))")
            } else if self.status != .stopping && self.status != .starting {
                self.status = .stopped
            }
        }
    }

    // MARK: - Startup Log & Window

    func appendLog(_ message: String) {
        startupLog.append(message)
    }

    @MainActor
    func showStartupWindow() {
        if let existing = startupWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = StartupLogView(appState: self) {
            NSApplication.shared.terminate(nil)
        }
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 400)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Maestro"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startupWindow = window
    }

    @MainActor
    func closeStartupWindow() {
        startupWindow?.close()
        startupWindow = nil
    }

    // MARK: - Password

    func resolvePassword() -> String {
        // 1. Check system env var
        if let envPassword = ProcessInfo.processInfo.environment["MAESTRO_PASSWORD"] {
            self.password = envPassword
            return envPassword
        }

        // 2. Check Keychain
        if let stored = KeychainManager.getPassword() {
            self.password = stored
            return stored
        }

        // 3. Generate and store
        let generated = KeychainManager.generatePassword()
        try? KeychainManager.setPassword(generated)
        self.password = generated
        return generated
    }

    // MARK: - Lifecycle

    func startMaestro() async {
        guard let projectDir = projectDirectory else { return }

        startupLog = []
        status = .starting

        await showStartupWindow()

        appendLog("Starting Maestro...")
        appendLog("Project: \(projectDir.path)")

        // Get version
        appendLog("Checking Maestro version...")
        maestroVersion = Self.queryVersion()
        if let version = maestroVersion {
            appendLog("Version: \(version)")
        } else {
            appendLog("Warning: Could not determine Maestro version")
        }

        // Wait for Docker
        appendLog("Checking Docker...")
        let dockerReady = await waitForDocker()
        if !dockerReady {
            appendLog("Startup cancelled.")
            status = .stopped
            return
        }
        appendLog("Docker is ready.")

        // Read port from Maestro config
        port = ConfigReader.readPort(projectDirectory: projectDir)
        appendLog("Port: \(port)")

        // Resolve password and generate session token
        let pass = resolvePassword()
        let token = SessionTokenGenerator.generate()
        sessionToken = token
        hasOpenedWebUI = false
        appendLog("Credentials configured.")

        // Launch process
        appendLog("Launching Maestro process...")
        do {
            try processManager.start(
                projectDirectory: projectDir,
                password: pass,
                sessionToken: token
            )
        } catch {
            appendLog("Error: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
            return
        }

        appendLog("Process launched. Waiting for server on port \(port)...")

        // Wait for server to be ready (may take a while on first run due to Docker image build)
        do {
            try await processManager.waitForPort(port)
            appendLog("Maestro is running!")
            status = .running
            await closeStartupWindow()
        } catch {
            // Check if the process is still running — if so, it's probably still starting up
            if processManager.isRunning {
                let msg = "Maestro is still starting (port \(port) not ready). Try Restart."
                appendLog(msg)
                status = .error(msg)
            } else {
                let msg = "Maestro failed to start. Check logs."
                appendLog(msg)
                status = .error(msg)
            }
        }
    }

    private static func queryVersion() -> String? {
        guard let binaryURL = Bundle.main.url(forResource: "maestro", withExtension: nil) else {
            return nil
        }
        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["-version"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // First line is "maestro <version>"
                return output.components(separatedBy: "\n").first
            }
        } catch {}
        return nil
    }

    /// Checks Docker availability. If not ready, logs status and polls every 3 seconds.
    /// Returns true when Docker is ready, or false if the user closes the startup window.
    @MainActor
    private func waitForDocker() async -> Bool {
        let initialStatus = await DockerChecker.check()
        if initialStatus == .ready { return true }

        if initialStatus == .notInstalled {
            appendLog("Docker not found. Please install Docker Desktop.")
            appendLog("Download: https://www.docker.com/products/docker-desktop/")
        } else {
            appendLog("Docker is not running. Please start Docker Desktop.")
        }
        appendLog("Waiting for Docker...")

        // Poll every 3 seconds for up to ~10 minutes
        for i in 0..<200 {
            try? await Task.sleep(for: .seconds(3))

            // If user closed the startup window, stop waiting
            if startupWindow == nil || !(startupWindow?.isVisible ?? false) {
                return false
            }

            if await DockerChecker.check() == .ready {
                return true
            }

            if i > 0 && (i + 1) % 10 == 0 {
                appendLog("Still waiting for Docker... (\((i + 1) * 3)s)")
            }
        }

        appendLog("Timed out waiting for Docker.")
        return false
    }

    func stopMaestro() {
        status = .stopped
        processManager.stop()
    }

    func restartMaestro() async {
        status = .stopping
        await processManager.stopAndWaitForPortRelease(port: port)
        status = .stopped
        await startMaestro()
    }
}
