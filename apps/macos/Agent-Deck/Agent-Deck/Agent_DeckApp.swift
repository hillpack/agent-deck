//
//  Agent_DeckApp.swift
//  Agent-Deck
//
//  Created by Agent Deck Team
//

import SwiftUI

/// Main app entry point for Agent Deck application
/// Converted from menubar app to standard dock app
@main
struct Agent_DeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main window
        WindowGroup {
            MainWindowView()
                .environmentObject(appDelegate)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 600)

        // Settings window (can be opened from menu)
        Settings {
            SettingsView()
        }
    }
}

/// Main window view that displays agent monitoring
struct MainWindowView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        Group {
            if let monitor = appDelegate.processMonitor,
               let winManager = appDelegate.windowManager,
               let config = appDelegate.configuration {
                MainContentView(
                    processMonitor: monitor,
                    windowManager: winManager,
                    configuration: config
                )
            } else {
                // Loading state while services initialize
                VStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Starting Agent Deck...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Main content view (adapted from MenuBarView)
struct MainContentView: View {
    @ObservedObject var processMonitor: ProcessMonitor
    var windowManager: WindowManager
    var configuration: Configuration
    @State private var showQRCode = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Agent list
            if processMonitor.instances.isEmpty {
                emptyStateView
            } else {
                agentListView
            }

            Divider()

            // Footer actions
            footerView
        }
        .frame(minWidth: 350, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            Text("Agent Deck")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Agent count badge
            if !processMonitor.instances.isEmpty {
                Text("\(processMonitor.instances.count) agent\(processMonitor.instances.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No agents detected")
                .font(.headline)

            Text("Launch Claude Code to start monitoring")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Hint
            Text("Agent Deck automatically detects running Claude Code sessions")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Agent List

    private var agentListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(processMonitor.instances) { instance in
                    AgentInstanceCard(instance: instance, windowManager: windowManager)
                }
            }
            .padding()
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 8) {
            // Mobile interface button
            Button(action: {
                showQRCode = true
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("View Mobile Interface")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .sheet(isPresented: $showQRCode) {
                QRCodeView(port: UInt16(configuration.server.port))
            }

            // Server status
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Server running on port \(configuration.server.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }
}
