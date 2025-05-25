import Foundation
import MCP

/// Extension to help create Values from Swift types
extension Value {
    init(_ any: Any) {
        if let string = any as? String {
            self = .string(string)
        } else if let int = any as? Int {
            self = .number(Double(int))
        } else if let double = any as? Double {
            self = .number(double)
        } else if let bool = any as? Bool {
            self = .boolean(bool)
        } else if let array = any as? [Any] {
            self = .array(array.map { Value($0) })
        } else if let dict = any as? [String: Any] {
            var object: [String: Value] = [:]
            for (key, value) in dict {
                object[key] = Value(value)
            }
            self = .object(object)
        } else {
            self = .null
        }
    }
}