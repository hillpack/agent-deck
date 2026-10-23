//
//  SettingsView.swift
//  Agent-Deck
//
//  Settings window with General, Agents, Mobile, and About tabs
//  Tasks: T081-T087 - Settings UI implementation
//

import SwiftUI
import AppKit

/// Settings window with tabbed interface
/// Tasks: T081-T087 - Four-tab settings window
struct SettingsView: View {
    // UserDefaults bindings for General settings
    @AppStorage("serverPort") private var serverPort: Int = 3000
    @AppStorage("autoStartOnLogin") private var autoStartOnLogin: Bool = false

    // State for Agents tab
    @State private var agentToggles: [String: Bool] = [:]
    @State private var configuration: Configuration?

    // State for error handling
    @State private var showError = false
    @State private var errorMessage = ""

    // Environment for dismissing window
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TabView {
            // Tab 1: General
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            // Tab 2: Agents
            agentsTab
                .tabItem {
                    Label("Agents", systemImage: "cpu")
                }

            // Tab 3: Mobile
            mobileTab
                .tabItem {
                    Label("Mobile", systemImage: "iphone")
                }

            // Tab 4: About
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadConfiguration()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Tab 1: General Settings

    private var generalTab: some View {
        Form {
            Section {
                // Server port configuration
                HStack {
                    Text("Server Port:")
                        .frame(width: 120, alignment: .leading)

                    TextField("Port", value: $serverPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .help("Port for HTTP and WebSocket server (1024-65535)")

                    Text("(default: 3000)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Changes require restart to take effect.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.leading, 120)

            } header: {
                Text("Server Configuration")
                    .font(.headline)
            }

            Spacer()
                .frame(height: 20)

            Section {
                // Auto-start on login
                Toggle(isOn: $autoStartOnLogin) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch Agent Deck at login")
                        Text("Automatically start monitoring when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: autoStartOnLogin) { newValue in
                    handleAutoStartChange(newValue)
                }

            } header: {
                Text("Startup")
                    .font(.headline)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Tab 2: Agents Settings

    private var agentsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Agent Types")
                    .font(.headline)

                Text("Enable or disable monitoring for specific agent types")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Divider()

            // Agent list
            if let config = configuration {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(config.agents, id: \.name) { agent in
                            agentRow(agent: agent)
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading configuration...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            }

            Spacer()

            // Save button
            HStack {
                Spacer()

                Button("Save Changes") {
                    saveAgentConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(configuration == nil)
            }
        }
        .padding(20)
    }

    private func agentRow(agent: Configuration.AgentPattern) -> some View {
        HStack(spacing: 16) {
            // Agent icon
            Image(systemName: iconForAgent(agent.name))
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Agent details
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text("Pattern: \(agent.processPattern)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { agentToggles[agent.name] ?? agent.enabled },
                set: { agentToggles[agent.name] = $0 }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Tab 3: Mobile Settings

    private var mobileTab: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Mobile Access")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Scan this QR code from your phone to access the mobile interface")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            Divider()

            // QR code and connection info
            QRCodeView(port: UInt16(serverPort))

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Tab 4: About

    private var aboutTab: some View {
        VStack(spacing: 20) {
            // App icon and name
            VStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Agent Deck")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.headline)

                Text("Agent Deck is a Stream Deck for AI agents. Monitor Claude Code, Cursor, and other agentic coding tools from your phone. Switch windows with one tap.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
                    .frame(height: 8)

                Text("Credits")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    creditRow(label: "Created by", value: "Agent Deck Team")
                    creditRow(label: "Platform", value: "macOS 12+ (Monterey)")
                    creditRow(label: "Framework", value: "Swift + SwiftUI")
                }

                Spacer()
                    .frame(height: 8)

                // GitHub link
                Link(destination: URL(string: "https://github.com/tonyofthehills/agent-deck")!) {
                    HStack {
                        Image(systemName: "link")
                        Text("View on GitHub")
                    }
                }
                .buttonStyle(.link)
            }

            Spacer()

            // Copyright
            Text("© 2025 Agent Deck Team. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding(20)
    }

    private func creditRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Helper Functions

    /// Load configuration from ConfigManager
    private func loadConfiguration() {
        do {
            let config = try ConfigManager.shared.loadConfiguration()
            self.configuration = config

            // Initialize agent toggles from config
            for agent in config.agents {
                agentToggles[agent.name] = agent.enabled
            }

            Logger.info("Settings: Configuration loaded", log: Logger.config)
        } catch {
            errorMessage = "Failed to load configuration: \(error.localizedDescription)"
            showError = true
            Logger.error("Settings: Failed to load configuration - \(error.localizedDescription)", log: Logger.config)
        }
    }

    /// Save agent configuration changes
    private func saveAgentConfiguration() {
        guard var config = configuration else { return }

        // Update agent enabled states
        for i in config.agents.indices {
            if let toggleState = agentToggles[config.agents[i].name] {
                // We can't modify config.agents[i].enabled directly since it's immutable
                // Instead, we need to create a new array with updated agents
                var updatedAgents = config.agents
                let agent = updatedAgents[i]
                updatedAgents[i] = Configuration.AgentPattern(
                    name: agent.name,
                    processPattern: agent.processPattern,
                    enabled: toggleState
                )
                config = Configuration(server: config.server, agents: updatedAgents)
            }
        }

        // Save to YAML file
        do {
            // Get config file path
            let configDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".agentdeck")
            let configFile = configDirectory.appendingPathComponent("config.yaml")

            // Encode to YAML
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(config)

            // Write to file
            try yamlString.write(to: configFile, atomically: true, encoding: .utf8)

            // Update local state
            self.configuration = config

            Logger.info("Settings: Agent configuration saved", log: Logger.config)

            // Show success feedback (brief)
            errorMessage = "Configuration saved successfully"
            showError = true

            // Notify user that restart is required
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                errorMessage = "Restart Agent Deck for changes to take effect"
                showError = true
            }

        } catch {
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
            showError = true
            Logger.error("Settings: Failed to save configuration - \(error.localizedDescription)", log: Logger.config)
        }
    }

    /// Handle auto-start on login toggle
    private func handleAutoStartChange(_ enabled: Bool) {
        ConfigManager.shared.saveAutoStartOnLogin(enabled)

        // TODO: Implement actual login item registration using SMLoginItemSetEnabled
        // For MVP, we just save the preference
        Logger.info("Settings: Auto-start on login set to \(enabled)", log: Logger.config)
    }

    /// Get SF Symbol icon for agent type
    private func iconForAgent(_ agentName: String) -> String {
        switch agentName.lowercased() {
        case let name where name.contains("claude"):
            return "cpu"
        case let name where name.contains("cursor"):
            return "cursorarrow.rays"
        case let name where name.contains("windsurf"):
            return "wind"
        default:
            return "command"
        }
    }

    /// Get app version from Info.plist
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }
}

// MARK: - YAMLEncoder Helper

import Yams

/// YAML encoder wrapper for Configuration
private struct YAMLEncoder {
    func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = Yams.YAMLEncoder()
        return try encoder.encode(value)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
