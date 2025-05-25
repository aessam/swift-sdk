import MCP
import Foundation
import SwiftUI
import Logging
import Collections

enum TransportType: String, CaseIterable, Identifiable {
    case http = "HTTP"
    case network = "Network (TCP)"
    case stdio = "Standard I/O"
    
    var id: String { rawValue }
}

@MainActor
class ServerViewModel: ObservableObject {
    // Connection settings
    @Published var serverURL = "http://localhost:8080"
    @Published var transportType: TransportType = .http
    @Published var isSecure = false
    @Published var isStreaming = true
    @Published var hostname = "localhost"
    @Published var port = "8080"
    
    // Connection state
    @Published var isConnecting = false
    @Published var isConnected = false
    @Published var connectionError: String?
    
    // Server info
    @Published var serverName = ""
    @Published var serverVersion = ""
    @Published var protocolVersion = ""
    
    // Server capabilities
    @Published var hasToolsCapability = false
    @Published var hasPromptsCapability = false
    @Published var hasResourcesCapability = false
    @Published var hasLoggingCapability = false
    
    // Tools
    @Published var availableTools: [Tool] = []
    @Published var selectedTool: Tool?
    @Published var toolResult: String?
    @Published var toolArguments: String = "{}"
    
    // Resources
    @Published var availableResources: [Resource] = []
    @Published var selectedResource: Resource?
    @Published var resourceContents: String?
    
    // Prompts
    @Published var availablePrompts: [Prompt] = []
    @Published var selectedPrompt: Prompt?
    @Published var promptArguments: String = "{}"
    @Published var promptMessages: String?
    
    private var client: Client?
    private var transport: (any Transport)?
    private let logger = Logger(label: "mcp.server.tester")
    
    func connect() async {
        guard !isConnected else { return }
        
        isConnecting = true
        connectionError = nil
        
        do {
            client = Client(name: "MCP Server Tester", version: "1.0.0")
            
            // Create transport based on selected type
            switch transportType {
            case .http:
                guard let url = URL(string: serverURL) else {
                    throw NSError(domain: "MCPServerTester", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                transport = HTTPClientTransport(endpoint: url, streaming: isStreaming)
                
            case .network:
                transport = NetworkTransport(endpoint: .hostPort(host: hostname, port: UInt16(port) ?? 8080))
                
            case .stdio:
                transport = StdioTransport()
            }
            
            // Connect to the server
            guard let transport = transport else {
                throw NSError(domain: "MCPServerTester", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create transport"])
            }
            
            try await client?.connect(transport: transport)
            
            // Initialize the connection
            if let result = try await client?.initialize() {
                // Update server info
                serverName = result.serverInfo.name
                serverVersion = result.serverInfo.version
                protocolVersion = result.protocolVersion
                
                // Update capabilities
                hasToolsCapability = result.capabilities.tools != nil
                hasPromptsCapability = result.capabilities.prompts != nil
                hasResourcesCapability = result.capabilities.resources != nil
                hasLoggingCapability = result.capabilities.logging != nil
                
                // Load initial data if available
                if hasToolsCapability {
                    await loadTools()
                }
                
                if hasResourcesCapability {
                    await loadResources()
                }
                
                if hasPromptsCapability {
                    await loadPrompts()
                }
                
                isConnected = true
            }
        } catch {
            connectionError = error.localizedDescription
            logger.error("Connection error: \(error)")
        }
        
        isConnecting = false
    }
    
    func disconnect() async {
        guard isConnected else { return }
        
        do {
            try await client?.disconnect()
            isConnected = false
            
            // Reset server data
            serverName = ""
            serverVersion = ""
            protocolVersion = ""
            
            // Reset capabilities
            hasToolsCapability = false
            hasPromptsCapability = false
            hasResourcesCapability = false
            hasLoggingCapability = false
            
            // Reset data
            availableTools = []
            availableResources = []
            availablePrompts = []
            
            selectedTool = nil
            selectedResource = nil
            selectedPrompt = nil
            
            toolResult = nil
            resourceContents = nil
            promptMessages = nil
            
            client = nil
            transport = nil
        } catch {
            logger.error("Disconnect error: \(error)")
            connectionError = error.localizedDescription
        }
    }
    
    // MARK: - Tools
    
    func loadTools() async {
        guard let client = client, hasToolsCapability else { return }
        
        do {
            let result = try await client.listTools()
            availableTools = result.tools
        } catch {
            logger.error("Error listing tools: \(error)")
        }
    }
    
    func callSelectedTool() async {
        guard let client = client, let tool = selectedTool else { return }
        
        do {
            // Parse JSON arguments
            let decoder = JSONDecoder()
            let argumentsData = toolArguments.data(using: .utf8) ?? Data()
            var arguments: [String: Value] = [:]
            
            if !argumentsData.isEmpty {
                let jsonObject = try JSONSerialization.jsonObject(with: argumentsData)
                if let dict = jsonObject as? [String: Any] {
                    for (key, value) in dict {
                        arguments[key] = Value(value)
                    }
                }
            }
            
            // Call the tool
            let result = try await client.callTool(name: tool.name, arguments: arguments)
            
            // Format the result
            var resultText = ""
            for content in result.content {
                switch content {
                case .text(let text):
                    resultText += "TEXT: \(text)\n"
                case .image(let data, let mimeType, let metadata):
                    resultText += "IMAGE: \(mimeType) (\(data.count) bytes)"
                    if let metadata = metadata {
                        resultText += " Metadata: \(metadata)\n"
                    } else {
                        resultText += "\n"
                    }
                case .audio(let data, let mimeType):
                    resultText += "AUDIO: \(mimeType) (\(data.count) bytes)\n"
                case .resource(let uri, let mimeType, let text):
                    resultText += "RESOURCE: \(uri) (\(mimeType))"
                    if let text = text {
                        resultText += " Text: \(text)\n"
                    } else {
                        resultText += "\n"
                    }
                }
            }
            
            toolResult = resultText
            if result.isError == true {
                toolResult = "ERROR: \(toolResult ?? "")"
            }
        } catch {
            toolResult = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Resources
    
    func loadResources() async {
        guard let client = client, hasResourcesCapability else { return }
        
        do {
            let result = try await client.listResources()
            availableResources = result.resources
        } catch {
            logger.error("Error listing resources: \(error)")
        }
    }
    
    func loadResourceContents() async {
        guard let client = client, let resource = selectedResource else { return }
        
        do {
            let result = try await client.readResource(uri: resource.uri)
            
            // Format the content
            var contentsText = ""
            for content in result.contents {
                switch content {
                case .text(let text):
                    contentsText += "TEXT: \(text)\n"
                case .image(let data, let mimeType, let metadata):
                    contentsText += "IMAGE: \(mimeType) (\(data.count) bytes)"
                    if let metadata = metadata {
                        contentsText += " Metadata: \(metadata)\n"
                    } else {
                        contentsText += "\n"
                    }
                case .audio(let data, let mimeType):
                    contentsText += "AUDIO: \(mimeType) (\(data.count) bytes)\n"
                case .resource(let uri, let mimeType, let text):
                    contentsText += "RESOURCE: \(uri) (\(mimeType))"
                    if let text = text {
                        contentsText += " Text: \(text)\n"
                    } else {
                        contentsText += "\n"
                    }
                }
            }
            
            resourceContents = contentsText
        } catch {
            resourceContents = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Prompts
    
    func loadPrompts() async {
        guard let client = client, hasPromptsCapability else { return }
        
        do {
            let result = try await client.listPrompts()
            availablePrompts = result.prompts
        } catch {
            logger.error("Error listing prompts: \(error)")
        }
    }
    
    func loadPromptMessages() async {
        guard let client = client, let prompt = selectedPrompt else { return }
        
        do {
            // Parse JSON arguments
            let decoder = JSONDecoder()
            let argumentsData = promptArguments.data(using: .utf8) ?? Data()
            var arguments: [String: Value] = [:]
            
            if !argumentsData.isEmpty {
                let jsonObject = try JSONSerialization.jsonObject(with: argumentsData)
                if let dict = jsonObject as? [String: Any] {
                    for (key, value) in dict {
                        arguments[key] = Value(value)
                    }
                }
            }
            
            // Get the prompt
            let result = try await client.getPrompt(name: prompt.name, arguments: arguments)
            
            // Format the messages
            var messagesText = "Description: \(result.description ?? "")\n\nMessages:\n"
            for message in result.messages {
                messagesText += "Role: \(message.role)\n"
                
                switch message.content {
                case .text(let text):
                    messagesText += "Content: \(text)\n\n"
                case .image(let data, let mimeType, _):
                    messagesText += "Content: Image \(mimeType) (\(data.count) bytes)\n\n"
                case .audio(let data, let mimeType):
                    messagesText += "Content: Audio \(mimeType) (\(data.count) bytes)\n\n"
                case .resource(let uri, let mimeType, _):
                    messagesText += "Content: Resource \(uri) (\(mimeType))\n\n"
                }
            }
            
            promptMessages = messagesText
        } catch {
            promptMessages = "Error: \(error.localizedDescription)"
        }
    }
}