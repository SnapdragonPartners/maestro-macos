//
//  ConfigReader.swift
//  Maestro App Factory
//

import Foundation

struct MaestroConfig: Codable {
    var webui: WebUIConfig?
}

struct WebUIConfig: Codable {
    var port: Int?
    var host: String?
}

struct ConfigReader {
    static func readPort(projectDirectory: URL) -> Int {
        let configURL = projectDirectory
            .appendingPathComponent(".maestro")
            .appendingPathComponent("config.json")

        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(MaestroConfig.self, from: data) else {
            return 8080
        }
        return config.webui?.port ?? 8080
    }
}
