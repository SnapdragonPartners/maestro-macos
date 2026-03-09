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

        // Give it 5 seconds to shut down gracefully
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            // If still running, force kill the process group
            if proc.isRunning {
                // Kill the entire process group (negative pid)
                kill(-pid, SIGKILL)
                // Also kill the process directly
                kill(pid, SIGKILL)
            }
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.process = nil
            }
        }
    }

    func waitForPort(_ port: Int, timeout: TimeInterval = 60) async throws {
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
