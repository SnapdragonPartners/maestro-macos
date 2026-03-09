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
                self.status = .error("Maestro exited unexpectedly (code \(status))")
            } else {
                self.status = .stopped
            }
        }
    }

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

    func startMaestro() async {
        guard let projectDir = projectDirectory else { return }

        status = .starting

        // Get version
        maestroVersion = Self.queryVersion()

        // Check Docker
        let dockerStatus = await DockerChecker.check()
        switch dockerStatus {
        case .notInstalled:
            DockerChecker.showNotInstalledAlert()
            status = .stopped
            return
        case .notRunning:
            DockerChecker.showNotRunningAlert()
            status = .stopped
            return
        case .ready:
            break
        }

        // Read port from Maestro config
        port = ConfigReader.readPort(projectDirectory: projectDir)

        // Resolve password and generate session token
        let pass = resolvePassword()
        let token = SessionTokenGenerator.generate()
        sessionToken = token
        hasOpenedWebUI = false

        // Launch process
        do {
            try processManager.start(
                projectDirectory: projectDir,
                password: pass,
                sessionToken: token
            )
        } catch {
            status = .error(error.localizedDescription)
            return
        }

        // Wait for server to be ready
        do {
            try await processManager.waitForPort(port)
            status = .running
        } catch {
            status = .error("Maestro started but web UI is not responding on port \(port).")
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

    func stopMaestro() {
        status = .stopped
        processManager.stop()
    }

    func restartMaestro() async {
        stopMaestro()
        // Brief pause to let process fully terminate
        try? await Task.sleep(for: .seconds(1))
        await startMaestro()
    }
}
