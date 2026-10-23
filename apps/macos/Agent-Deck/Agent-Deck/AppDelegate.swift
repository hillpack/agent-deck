//
//  AppDelegate.swift
//  Agent-Deck
//
//  Created by Agent Deck Team
//

import Cocoa
import SwiftUI
import Combine

/// AppDelegate for dock app lifecycle management
/// Converted from menubar app to standard dock app (Nov 2025)
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // Services - Phase 3 (User Story 1)
    @Published var processMonitor: ProcessMonitor?
    @Published var webSocketServer: WebSocketServer?
    @Published var httpServer: HTTPServer?
    @Published var windowManager: WindowManager? // Phase 4 (User Story 2)

    // Configuration
    @Published var configuration: Configuration?

    // Combine subscriptions for observing ProcessMonitor changes
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 Agent Deck launching...")
        Logger.info("Agent Deck launching...")

        // First-launch detection (Task: T074)
        handleFirstLaunch()

        // Load configuration
        let config = loadConfiguration()
        NSLog("✅ Config loaded - port: \(config.server.port)")

        // Store configuration for later use
        self.configuration = config

        // Initialize services (Phase 3)
        NSLog("🔧 Starting setupServices...")
        setupServices(config: config)
        NSLog("✅ setupServices complete")

        // Prompt for accessibility permissions if not granted (Task: T076)
        checkAndPromptForAccessibilityPermissions()

        Logger.info("Agent Deck launched successfully")
        NSLog("🎉 Agent Deck launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("Agent Deck terminating...")
        NSLog("🛑 Agent Deck shutting down...")

        // Clean shutdown (Task: T078-T080)
        performCleanShutdown()

        Logger.info("Agent Deck terminated")
        NSLog("✅ Agent Deck terminated cleanly")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running even if window is closed (like a traditional dock app)
        // User can quit via Cmd+Q or File > Quit
        return false
    }

    /// Load configuration on launch
    private func loadConfiguration() -> Configuration {
        do {
            let config = try ConfigManager.shared.loadConfiguration()
            Logger.info("Configuration loaded: \(config.agents.count) agent patterns", log: Logger.config)
            return config
        } catch {
            Logger.error("Failed to load configuration: \(error.localizedDescription)", log: Logger.config)

            // Return default configuration
            return Configuration.default
        }
    }

    /// Setup services (Phase 3 - User Story 1)
    private func setupServices(config: Configuration) {
        NSLog("📦 Initializing WindowManager...")
        windowManager = WindowManager()

        NSLog("📦 Initializing ProcessMonitor...")
        processMonitor = ProcessMonitor()
        processMonitor?.startMonitoring(configuration: config)

        // Get WebRoot path from bundle resources
        // Note: PWA files are directly in Resources/, not Resources/WebRoot/
        let webRootPath = Bundle.main.resourcePath ?? ""
        NSLog("📁 WebRoot path: \(webRootPath)")

        // Initialize HTTPServer (serves PWA files on port 3000)
        NSLog("📦 Initializing HTTPServer on port \(config.server.port)...")
        httpServer = HTTPServer(port: UInt16(config.server.port), webRootPath: webRootPath)

        // Initialize WebSocketServer (WebSocket on port 3001 to avoid conflict)
        // TODO: Ideally HTTP server should handle WebSocket upgrades, but for MVP we use separate ports
        NSLog("📦 Initializing WebSocketServer on port \(config.server.port + 1)...")
        webSocketServer = WebSocketServer(port: UInt16(config.server.port + 1))
        webSocketServer?.processMonitor = processMonitor
        webSocketServer?.windowManager = windowManager

        // Start servers
        NSLog("🚀 Starting servers...")
        do {
            NSLog("  Starting WebSocketServer...")
            try webSocketServer?.start()
            NSLog("  ✅ WebSocketServer started")

            NSLog("  Starting HTTPServer...")
            try httpServer?.start()
            NSLog("  ✅ HTTPServer started")

            Logger.info("Servers started on port \(config.server.port)", log: Logger.network)
            NSLog("🎉 All servers started successfully!")
        } catch {
            NSLog("❌ Server start error: \(error)")
            Logger.error("Failed to start servers: \(error.localizedDescription)", log: Logger.network)

            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Server Start Failed"
            alert.informativeText = "Could not start WebSocket/HTTP server on port \(config.server.port). Port may be in use.\n\nError: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }

        // Observe ProcessMonitor changes and broadcast to WebSocket clients
        NSLog("👁️ Setting up ProcessMonitor observation...")
        observeProcessMonitorChanges()
    }

    /// Observe ProcessMonitor changes and broadcast updates
    private func observeProcessMonitorChanges() {
        guard let monitor = processMonitor, let wsServer = webSocketServer else { return }

        // Use Combine to observe ProcessMonitor.$instances changes
        // When instances change, broadcast full state to all WebSocket clients
        monitor.$instances
            .dropFirst() // Skip initial empty state
            .sink { [weak self, weak wsServer] instances in
                guard let wsServer = wsServer else { return }

                Logger.info("ProcessMonitor instances changed, broadcasting to \(wsServer.connections.count) clients", log: Logger.monitoring)

                // Broadcast full state update
                // Matches TypeScript shared-types/src/websocket.ts StatusUpdateMessage
                let message: [String: Any] = [
                    "type": "update",  // TypeScript expects "update", not "state_update"
                    "instances": instances.map { $0.toDictionary() }
                ]

                wsServer.broadcastMessage(message)
            }
            .store(in: &cancellables)

        Logger.info("ProcessMonitor observation configured with Combine", log: Logger.monitoring)
    }

    // MARK: - First Launch Handling

    /// Handle first-launch setup (Task: T074)
    /// Detects if this is the first time the app has launched and performs initial setup
    private func handleFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if !hasLaunchedBefore {
            NSLog("🎉 First launch detected!")
            Logger.info("First launch - performing initial setup", log: Logger.general)

            // Show welcome message (optional for MVP)
            showWelcomeMessage()

            // Mark as launched
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            UserDefaults.standard.synchronize()

            Logger.info("First launch setup complete", log: Logger.general)
        } else {
            Logger.info("Subsequent launch", log: Logger.general)
        }
    }

    /// Show welcome message on first launch
    private func showWelcomeMessage() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Agent Deck!"
        alert.informativeText = """
        Agent Deck monitors your AI coding assistants and provides a mobile control interface.

        To get started:
        1. Grant Accessibility permissions when prompted
        2. The app will show detected agent instances
        3. Scan the QR code with your phone to access the mobile interface

        Configuration file created at: ~/.agentdeck/config.yaml
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Get Started")
        alert.runModal()
    }

    // MARK: - Accessibility Permissions

    /// Check and prompt for accessibility permissions if needed (Task: T076-T077)
    private func checkAndPromptForAccessibilityPermissions() {
        guard let winManager = windowManager else { return }

        // Check if accessibility permissions are granted
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessibilityEnabled {
            NSLog("⚠️ Accessibility permissions not granted")
            Logger.warning("Accessibility permissions not granted - prompting user", log: Logger.general)

            // Show explanation dialog
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = """
            Agent Deck needs Accessibility permissions to switch between application windows.

            What to do:
            1. Click "Open System Settings" below
            2. Enable "Agent Deck" in the Accessibility list
            3. Restart Agent Deck

            Window switching will not work until permissions are granted.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Remind Me Later")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // User clicked "Open System Settings"
                Logger.info("User chose to open System Settings", log: Logger.general)

                // Trigger system permission dialog
                winManager.promptForAccessibilityPermissions()

                // Open System Settings to Privacy & Security > Accessibility
                // Note: The direct URL scheme was removed in recent macOS versions
                // The promptForAccessibilityPermissions() call above will show the dialog
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                Logger.info("User chose to skip accessibility permissions", log: Logger.general)
            }
        } else {
            NSLog("✅ Accessibility permissions already granted")
            Logger.info("Accessibility permissions granted", log: Logger.general)
        }
    }

    // MARK: - Clean Shutdown

    /// Perform clean shutdown of all services (Task: T078-T080)
    private func performCleanShutdown() {
        NSLog("🔧 Stopping services...")

        // 1. Stop process monitoring (stops timers and FSEvents)
        if let monitor = processMonitor {
            NSLog("  Stopping ProcessMonitor...")
            monitor.stopMonitoring()
            NSLog("  ✅ ProcessMonitor stopped")
        }

        // 2. Stop WebSocket server (closes all connections)
        if let wsServer = webSocketServer {
            NSLog("  Stopping WebSocketServer...")
            wsServer.stop()
            NSLog("  ✅ WebSocketServer stopped")
        }

        // 3. Stop HTTP server (closes listener)
        if let httpSrv = httpServer {
            NSLog("  Stopping HTTPServer...")
            httpSrv.stop()
            NSLog("  ✅ HTTPServer stopped")
        }

        // 4. Cancel all Combine subscriptions
        NSLog("  Cancelling Combine subscriptions...")
        cancellables.removeAll()
        NSLog("  ✅ Combine subscriptions cancelled")

        // 5. Clear references to services
        processMonitor = nil
        webSocketServer = nil
        httpServer = nil
        windowManager = nil

        Logger.info("All services stopped cleanly", log: Logger.general)
        NSLog("🎉 Clean shutdown complete")
    }
}
