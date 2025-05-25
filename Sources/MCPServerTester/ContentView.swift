import SwiftUI
import MCP

struct ContentView: View {
    @EnvironmentObject private var viewModel: ServerViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            // Title bar
            HStack {
                Text("MCP Server Tester")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                        Text("Connected")
                    }
                    .transition(.opacity)
                }
            }
            .padding()
            
            // Connection configuration and status
            ConnectionView()
                .padding(.horizontal)
            
            if viewModel.isConnected {
                // Server information
                ServerInfoView()
                    .padding(.horizontal)
                    .padding(.top)
                
                Divider()
                    .padding(.vertical)
                
                // Tab view for capabilities
                TabView(selection: $selectedTab) {
                    if viewModel.hasToolsCapability {
                        ToolsView()
                            .tabItem {
                                Image(systemName: "hammer")
                                Text("Tools")
                            }
                            .tag(0)
                    }
                    
                    if viewModel.hasResourcesCapability {
                        ResourcesView()
                            .tabItem {
                                Image(systemName: "doc")
                                Text("Resources")
                            }
                            .tag(1)
                    }
                    
                    if viewModel.hasPromptsCapability {
                        PromptsView()
                            .tabItem {
                                Image(systemName: "bubble.left")
                                Text("Prompts")
                            }
                            .tag(2)
                    }
                }
                .padding(.horizontal)
                .animation(.default, value: selectedTab)
            } else {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Configure connection settings and click Connect")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Connection View

struct ConnectionView: View {
    @EnvironmentObject private var viewModel: ServerViewModel
    
    var body: some View {
        GroupBox("Connection Settings") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 20) {
                    // Transport type
                    VStack(alignment: .leading) {
                        Text("Transport Type")
                            .font(.headline)
                        
                        Picker("", selection: $viewModel.transportType) {
                            ForEach(TransportType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    
                    // Server URL or host:port settings
                    VStack(alignment: .leading) {
                        if viewModel.transportType == .http {
                            Text("Server URL")
                                .font(.headline)
                            
                            TextField("http://localhost:8080", text: $viewModel.serverURL)
                                .frame(width: 300)
                            
                            Toggle("Use streaming", isOn: $viewModel.isStreaming)
                                .padding(.top, 4)
                        } else if viewModel.transportType == .network {
                            Text("Server Host and Port")
                                .font(.headline)
                            
                            HStack {
                                TextField("localhost", text: $viewModel.hostname)
                                    .frame(width: 200)
                                
                                Text(":")
                                
                                TextField("8080", text: $viewModel.port)
                                    .frame(width: 80)
                            }
                        } else {
                            Text("Standard I/O Transport")
                                .font(.headline)
                            
                            Text("Uses standard input and output streams")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Connect/Disconnect button
                    VStack {
                        if !viewModel.isConnected {
                            Button {
                                Task {
                                    await viewModel.connect()
                                }
                            } label: {
                                if viewModel.isConnecting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                    Text("Connecting...")
                                } else {
                                    Text("Connect")
                                }
                            }
                            .disabled(viewModel.isConnecting)
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Disconnect") {
                                Task {
                                    await viewModel.disconnect()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Error display
                if let error = viewModel.connectionError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()
        }
    }
}

// MARK: - Server Info View

struct ServerInfoView: View {
    @EnvironmentObject private var viewModel: ServerViewModel
    
    var body: some View {
        GroupBox("Server Information") {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Name:")
                        .bold()
                    Text(viewModel.serverName)
                    
                    Text("Version:")
                        .bold()
                    Text(viewModel.serverVersion)
                    
                    Text("Protocol:")
                        .bold()
                    Text(viewModel.protocolVersion)
                }
                
                GridRow {
                    Text("Capabilities:")
                        .bold()
                    
                    HStack(spacing: 12) {
                        CapabilityBadge(
                            name: "Tools",
                            isEnabled: viewModel.hasToolsCapability,
                            icon: "hammer"
                        )
                        
                        CapabilityBadge(
                            name: "Resources",
                            isEnabled: viewModel.hasResourcesCapability,
                            icon: "doc"
                        )
                        
                        CapabilityBadge(
                            name: "Prompts",
                            isEnabled: viewModel.hasPromptsCapability,
                            icon: "bubble.left"
                        )
                        
                        CapabilityBadge(
                            name: "Logging",
                            isEnabled: viewModel.hasLoggingCapability,
                            icon: "text.book.closed"
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Tools View

struct ToolsView: View {
    @EnvironmentObject private var viewModel: ServerViewModel
    @State private var isCallingTool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                // Available tools list
                VStack(alignment: .leading) {
                    Text("Available Tools")
                        .font(.headline)
                    
                    List(viewModel.availableTools, id: \.name) { tool in
                        VStack(alignment: .leading) {
                            Text(tool.name)
                                .font(.headline)
                            Text(tool.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                        .background(
                            viewModel.selectedTool?.name == tool.name ? 
                                Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedTool = tool
                        }
                    }
                    .frame(width: 250, height: 300)
                    .overlay {
                        if viewModel.availableTools.isEmpty {
                            Text("No tools available")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Refresh Tools") {
                        Task {
                            await viewModel.loadTools()
                        }
                    }
                    .padding(.top, 8)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Tool details and execution
                if let tool = viewModel.selectedTool {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tool Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name: \(tool.name)")
                            Text("Description: \(tool.description)")
                                .lineLimit(3)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        Text("Arguments (JSON)")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.toolArguments)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        
                        HStack {
                            Spacer()
                            
                            Button {
                                isCallingTool = true
                                Task {
                                    await viewModel.callSelectedTool()
                                    isCallingTool = false
                                }
                            } label: {
                                if isCallingTool {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                    Text("Calling...")
                                } else {
                                    Text("Call Tool")
                                }
                            }
                            .disabled(isCallingTool)
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Text("Result")
                            .font(.headline)
                        
                        if let result = viewModel.toolResult {
                            ScrollView {
                                Text(result)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            Text("Call the tool to see results")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Select a tool to view details")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Resources View

struct ResourcesView: View {
    @EnvironmentObject private var viewModel: ServerViewModel
    @State private var isLoadingResource = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                // Available resources list
                VStack(alignment: .leading) {
                    Text("Available Resources")
                        .font(.headline)
                    
                    List(viewModel.availableResources, id: \.uri) { resource in
                        VStack(alignment: .leading) {
                            Text(resource.uri)
                                .font(.headline)
                            if let description = resource.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                        .background(
                            viewModel.selectedResource?.uri == resource.uri ? 
                                Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedResource = resource
                            viewModel.resourceContents = nil
                        }
                    }
                    .frame(width: 250, height: 300)
                    .overlay {
                        if viewModel.availableResources.isEmpty {
                            Text("No resources available")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Refresh Resources") {
                        Task {
                            await viewModel.loadResources()
                        }
                    }
                    .padding(.top, 8)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Resource details
                if let resource = viewModel.selectedResource {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resource Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URI: \(resource.uri)")
                            if let description = resource.description {
                                Text("Description: \(description)")
                                    .lineLimit(3)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack {
                            Spacer()
                            
                            Button {
                                isLoadingResource = true
                                Task {
                                    await viewModel.loadResourceContents()
                                    isLoadingResource = false
                                }
                            } label: {
                                if isLoadingResource {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                    Text("Loading...")
                                } else {
                                    Text("Load Resource")
                                }
                            }
                            .disabled(isLoadingResource)
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Text("Contents")
                            .font(.headline)
                        
                        if let contents = viewModel.resourceContents {
                            ScrollView {
                                Text(contents)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 150)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            Text("Load the resource to see contents")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 150)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Select a resource to view details")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Prompts View

struct PromptsView: View {
    @EnvironmentObject private var viewModel: ServerViewModel
    @State private var isLoadingPrompt = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                // Available prompts list
                VStack(alignment: .leading) {
                    Text("Available Prompts")
                        .font(.headline)
                    
                    List(viewModel.availablePrompts, id: \.name) { prompt in
                        VStack(alignment: .leading) {
                            Text(prompt.name)
                                .font(.headline)
                            if let description = prompt.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                        .background(
                            viewModel.selectedPrompt?.name == prompt.name ? 
                                Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedPrompt = prompt
                            viewModel.promptMessages = nil
                        }
                    }
                    .frame(width: 250, height: 300)
                    .overlay {
                        if viewModel.availablePrompts.isEmpty {
                            Text("No prompts available")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Refresh Prompts") {
                        Task {
                            await viewModel.loadPrompts()
                        }
                    }
                    .padding(.top, 8)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Prompt details
                if let prompt = viewModel.selectedPrompt {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prompt Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name: \(prompt.name)")
                            if let description = prompt.description {
                                Text("Description: \(description)")
                                    .lineLimit(3)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        Text("Arguments (JSON)")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.promptArguments)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        
                        HStack {
                            Spacer()
                            
                            Button {
                                isLoadingPrompt = true
                                Task {
                                    await viewModel.loadPromptMessages()
                                    isLoadingPrompt = false
                                }
                            } label: {
                                if isLoadingPrompt {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                    Text("Loading...")
                                } else {
                                    Text("Get Messages")
                                }
                            }
                            .disabled(isLoadingPrompt)
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Text("Messages")
                            .font(.headline)
                        
                        if let messages = viewModel.promptMessages {
                            ScrollView {
                                Text(messages)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            Text("Get messages to view content")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Select a prompt to view details")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct CapabilityBadge: View {
    let name: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(name)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isEnabled ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
        .foregroundColor(isEnabled ? .green : .secondary)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ServerViewModel())
}