//
//  MenuBarView.swift
//  Agent-Deck
//
//  Menubar dropdown view displaying detected agent instances
//  Spec: tasks.md T031-T032
//

import SwiftUI

/// Menubar popover view showing list of detected agent instances
/// Tasks: T031-T032 - display agent list with status indicators
struct MenuBarView: View {
    @ObservedObject var processMonitor: ProcessMonitor
    var windowManager: WindowManager
    var configuration: Configuration
    @State private var showQRCode = false
    @State private var showSettings = false

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
        .frame(width: 300, height: 400)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.system(size: 16))
            Text("Agent Deck")
                .font(.headline)

            Spacer()

            Text("\(processMonitor.instances.count)")
                .font(.caption)
                .foregroundColor(.secondary)
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
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
        VStack(spacing: 0) {
            // Mobile interface button
            // Task: T059 - add "View Mobile Interface" menu item
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
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.top, 8)
            .sheet(isPresented: $showQRCode) {
                QRCodeView(port: UInt16(configuration.server.port))
            }

            // Settings and Quit buttons
            HStack {
                Button(action: {
                    showSettings = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .font(.caption)
        }
    }
}

/// Individual agent instance card
/// Task: T032 - display with status indicators
/// Task: T051-T052 - tap event handler to focus window
struct AgentInstanceCard: View {
    let instance: AgentInstance
    var windowManager: WindowManager
    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator (smaller, less prominent)
            statusIndicator
                .opacity(0.6)

            // Instance details
            VStack(alignment: .leading, spacing: 6) {
                // Agent type and working directory on one line
                HStack(spacing: 8) {
                    Text(instance.agentType.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(instance.workingDirectory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Current task (PROMINENT - what the user wants to see)
                if let task = instance.currentTask {
                    Text(task)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                } else {
                    // Show idle status if no task
                    Text("Idle - waiting for input")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }

                // Status text with timestamp
                HStack(spacing: 4) {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(formatTimestamp(instance.lastActivityTimestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // PID badge
            Text("PID \(instance.pid)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(0.3), lineWidth: isPressed ? 2 : 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                           pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .help("Click to focus this instance")
    }

    // MARK: - Tap Handler

    private func handleTap() {
        NSLog("🖱️ Menubar card tapped for PID \(instance.pid), cwd: \(instance.workingDirectory)")

        let result = windowManager.focusWindow(pid: instance.pid, cwd: instance.workingDirectory)

        switch result {
        case .success:
            NSLog("✅ Window focused successfully from menubar")
            // Optionally close the menubar popover
            // NSApp.hide(nil)

        case .failure(let error):
            NSLog("❌ Window focus failed: \(error.localizedDescription)")

            // Show alert to user
            let alert = NSAlert()
            alert.messageText = "Failed to Focus Window"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
    }

    private var statusColor: Color {
        switch instance.status {
        case .idle:
            return Color(hex: "#888888")
        case .working:
            return Color(hex: "#0066CC")
        case .done:
            return Color(hex: "#00AA00")
        case .error:
            return Color(hex: "#CC0000")
        }
    }

    private var statusText: String {
        switch instance.status {
        case .idle:
            return "Idle"
        case .working:
            return "Working"
        case .done:
            return "Done"
        case .error:
            return "Error"
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Preview

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        let monitor = ProcessMonitor()
        let windowManager = WindowManager()
        let configuration = Configuration.default
        return MenuBarView(processMonitor: monitor, windowManager: windowManager, configuration: configuration)
    }
}
