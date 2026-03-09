//
//  SessionTokenGenerator.swift
//  Maestro App Factory
//

import Foundation
import Security

struct SessionTokenGenerator {
    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
