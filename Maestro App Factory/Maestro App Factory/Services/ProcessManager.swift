//
//  ProcessManager.swift
//  Maestro App Factory
//

import Foundation

@Observable
class ProcessManager {
    private var process: Process?
    private var logHandle: FileHandle?
    private(set) var isRunning = false

    var onTermination: ((Process.TerminationReason, Int32) -> Void)?

    func start(projectDirectory: URL, password: String, sessionToken: String) throws {
        guard !isRunning else { return }

        guard let binaryURL = Bundle.main.url(forResource: "maestro", withExtension: nil) else {
            throw ProcessError.binaryNotFound
        }

        let logFile = try LogManager.createLogFile()
        self.logHandle = logFile

        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["-projectdir", projectDirectory.path]

        // Inherit parent environment and add our vars
        var env = ProcessInfo.processInfo.environment
        env["MAESTRO_PASSWORD"] = password
        env["MAESTRO_SESSION_TOKEN"] = sessionToken

        // When launched from Finder/DMG, PATH is minimal and won't include
        // Docker or Homebrew paths. Resolve the user's real PATH via login shell.
        if let shellPath = Self.resolveUserPath() {
            env["PATH"] = shellPath
        }

        proc.environment = env

        proc.standardOutput = logFile
        proc.standardError = logFile

        // Create a new process group so we can kill all children
        proc.qualityOfService = .userInitiated

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.logHandle = nil
                self?.onTermination?(process.terminationReason, process.terminationStatus)
            }
        }

        try proc.run()
        self.process = proc
        self.isRunning = true
    }

    func stop() {
        guard let proc = process else {
            isRunning = false
            return
        }

        let pid = proc.processIdentifier
        guard pid > 0 else {
            isRunning = false
            process = nil
            return
        }

        // Send SIGINT first (Go handles graceful shutdown on interrupt)
        kill(pid, SIGINT)

        // Wait synchronously for up to 5 seconds
        proc.waitUntilExit()

        // If it somehow didn't exit, force kill
        if proc.isRunning {
            kill(-pid, SIGKILL)
            kill(pid, SIGKILL)
            proc.waitUntilExit()
        }

        isRunning = false
        process = nil
    }

    /// Async stop that waits for the process to fully terminate and the port to be released
    func stopAndWaitForPortRelease(port: Int) async {
        stop()

        // Wait for port to actually be released
        let start = Date()
        while Date().timeIntervalSince(start) < 10 {
            let available = await isPortAvailable(port)
            if available { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func isPortAvailable(_ port: Int) async -> Bool {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1
        let session = URLSession(configuration: config)
        do {
            let _ = try await session.data(from: URL(string: "http://localhost:\(port)")!)
            return false // Still responding
        } catch {
            return true // Connection refused = port is free
        }
    }

    /// Resolve the user's full PATH by running a login shell.
    /// This ensures we get the same PATH the user would have in Terminal,
    /// including Homebrew, Docker, etc.
    private static func resolveUserPath() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {}
        return nil
    }

    func waitForPort(_ port: Int, timeout: TimeInterval = 300) async throws {
        let start = Date()
        let url = URL(string: "http://localhost:\(port)")!

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: config)

        while Date().timeIntervalSince(start) < timeout {
            do {
                let (_, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode > 0 {
                    return
                }
            } catch {
                // Server not ready yet
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw ProcessError.portTimeout(port)
    }
}

enum ProcessError: LocalizedError {
    case binaryNotFound
    case portTimeout(Int)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Maestro binary not found in app bundle."
        case .portTimeout(let port):
            return "Maestro failed to start on port \(port)."
        }
    }
}
