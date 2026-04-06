//
//  ExtensionConfig.swift
//  Helios
//
//  Extension registry for Helios plugins/providers.
//  Also defines the JSONValue type used for type-safe JSON representation.
//

import Foundation

// MARK: - JSONValue

/// A type-safe, Sendable, Codable representation of a JSON value.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:            try container.encodeNil()
        case .bool(let b):     try container.encode(b)
        case .int(let i):      try container.encode(i)
        case .double(let d):   try container.encode(d)
        case .string(let s):   try container.encode(s)
        case .array(let a):    try container.encode(a)
        case .object(let o):   try container.encode(o)
        }
    }

    // MARK: Convenience accessors

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var intValue: Int? {
        if case .int(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Subscript access for `.object` values.
    public subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    /// Subscript access for `.array` values.
    public subscript(index: Int) -> JSONValue? {
        guard let a = arrayValue, index >= 0, index < a.count else { return nil }
        return a[index]
    }
}

// MARK: - ExpressibleBy literals

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}
extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}
extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}
extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - ExtensionKind

/// The kind of component a registered extension provides.
public enum ExtensionKind: String, CaseIterable, Codable, Sendable {
    case service
    case middleware
    case routeProvider
    case backgroundTask
    case timer
    case storage
}

// MARK: - ExtensionDescriptor

/// Metadata describing a single registered Helios extension.
public struct ExtensionDescriptor: Codable, Sendable {
    /// Unique identifier for this extension (e.g. "payments", "oauth").
    public let key: String
    /// Whether this extension is active. Disabled extensions are skipped during bootstrap.
    public let enabled: Bool
    /// The kind of component this extension provides.
    public let kind: ExtensionKind
    /// Optional extension-specific configuration as a typed JSON value.
    public let config: JSONValue?

    public init(key: String, enabled: Bool = true, kind: ExtensionKind, config: JSONValue? = nil) {
        self.key = key
        self.enabled = enabled
        self.kind = kind
        self.config = config
    }
}

// MARK: - ExtensionConfig

/// Registry of Helios extensions (plugins/providers) for an application.
public struct ExtensionConfig: Codable, Sendable {

    /// All registered extension descriptors.
    public let descriptors: [ExtensionDescriptor]

    public init(descriptors: [ExtensionDescriptor] = []) {
        self.descriptors = descriptors
    }

    /// Returns only descriptors that are enabled.
    public var enabled: [ExtensionDescriptor] {
        descriptors.filter(\.enabled)
    }

    /// Returns descriptors of a specific kind.
    public func descriptors(ofKind kind: ExtensionKind) -> [ExtensionDescriptor] {
        descriptors.filter { $0.kind == kind }
    }

    /// Returns the descriptor with the given key, if any.
    public func descriptor(forKey key: String) -> ExtensionDescriptor? {
        descriptors.first { $0.key == key }
    }

    /// Empty registry — no extensions registered.
    public static let empty = ExtensionConfig(descriptors: [])
}
