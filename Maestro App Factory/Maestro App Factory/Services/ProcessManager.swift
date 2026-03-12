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

        // The shell environment (from login shell) is the base — it has PATH,
        // API keys, and everything the user would have in Terminal.
        // We only add MAESTRO_PASSWORD and MAESTRO_SESSION_TOKEN on top.
        var env = Self.resolveUserEnvironment()
        env["MAESTRO_PASSWORD"] = password
        env["MAESTRO_SESSION_TOKEN"] = sessionToken

        proc.environment = env

        proc.standardOutput = logFile
        proc.standardError = logFile

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

        // Give it up to 5 seconds to exit gracefully
        let deadline = Date().addingTimeInterval(5)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        // If still running, force kill
        if proc.isRunning {
            kill(pid, SIGKILL)
            proc.waitUntilExit()
        }

        // Kill any orphaned child processes
        Self.killChildProcesses(parentPID: pid)

        isRunning = false
        process = nil
    }

    /// Find and kill all child processes of the given PID
    private static func killChildProcesses(parentPID: pid_t) {
        let pipe = Pipe()
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-P", "\(parentPID)"]
        pgrep.standardOutput = pipe
        pgrep.standardError = FileHandle.nullDevice

        do {
            try pgrep.run()
            pgrep.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.split(separator: "\n") {
                    if let childPID = pid_t(line.trimmingCharacters(in: .whitespaces)) {
                        kill(childPID, SIGKILL)
                    }
                }
            }
        } catch {}
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

    /// Resolve the user's full shell environment by running a login shell.
    /// This ensures we get PATH, API keys, and everything else from .zshrc/.zprofile.
    private static func resolveUserEnvironment() -> [String: String] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "env"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [:] }
            var env: [String: String] = [:]
            for line in output.components(separatedBy: "\n") {
                guard let eqIndex = line.firstIndex(of: "=") else { continue }
                let key = String(line[line.startIndex..<eqIndex])
                let value = String(line[line.index(after: eqIndex)...])
                if !key.isEmpty {
                    env[key] = value
                }
            }
            return env
        } catch {
            return [:]
        }
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
