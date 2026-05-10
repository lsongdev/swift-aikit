//
//  JSONEncoder+Stable.swift
//  ChatClientKit
//

import Foundation

extension JSONEncoder {
    /// Encoder that produces deterministic JSON suitable for prefix caching.
    ///
    /// Tool schemas and other request fields contain dictionaries whose default
    /// iteration order is hash-randomized per process; without sorted keys, the
    /// serialized request body changes between turns and breaks prompt prefix
    /// caching on remote inference servers (e.g. llama.cpp).
    static var stableRequestEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
