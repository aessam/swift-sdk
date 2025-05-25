import Foundation
import MCP

// Make Tool identifiable for SwiftUI
extension Tool: Identifiable {
    public var id: String { name }
}

// Make Resource identifiable for SwiftUI
extension Resource: Identifiable {
    public var id: String { uri }
}

// Make Prompt identifiable for SwiftUI
extension Prompt: Identifiable {
    public var id: String { name }
}