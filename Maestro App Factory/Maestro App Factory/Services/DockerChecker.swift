//
//  DockerChecker.swift
//  Maestro App Factory
//

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

}
