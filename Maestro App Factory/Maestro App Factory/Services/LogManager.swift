//
//  LogManager.swift
//  Maestro App Factory
//

import AppKit
import Foundation

struct LogManager {
    private static var logDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Maestro").appendingPathComponent("logs")
    }

    static func createLogFile() throws -> FileHandle {
        let dir = logDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "maestro-\(formatter.string(from: Date())).log"
        let fileURL = dir.appendingPathComponent(filename)

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        return try FileHandle(forWritingTo: fileURL)
    }

    static func openLogDirectory() {
        NSWorkspace.shared.open(logDirectory)
    }
}
