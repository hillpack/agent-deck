//
//  WindowManager.swift
//  Agent-Deck
//
//  Window management service for switching focus to agent windows via AppleScript
//  Spec: tasks.md T042-T046, contracts/websocket-protocol.md
//

import Foundation
import AppKit

/// Error types for window management operations
enum WindowManagerError: Error, LocalizedError {
    case accessibilityPermissionsRequired
    case instanceNotFound
    case windowNotFound
    case applescriptError(String)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionsRequired:
            return "Agent Deck needs Accessibility permissions to switch windows. Please grant permission in System Preferences > Privacy & Security > Accessibility."
        case .instanceNotFound:
            return "Instance no longer exists"
        case .windowNotFound:
            return "Window ID invalid or process has no window"
        case .applescriptError(let message):
            return "AppleScript execution failed: \(message)"
        }
    }

    var errorCode: String {
        switch self {
        case .accessibilityPermissionsRequired:
            return "accessibility_permissions_required"
        case .instanceNotFound:
            return "instance_not_found"
        case .windowNotFound:
            return "window_not_found"
        case .applescriptError:
            return "applescript_error"
        }
    }
}

/// Service responsible for switching window focus to agent instances
/// Uses AppleScript to bring windows to front, including across macOS Spaces
class WindowManager {

    // Track permission check state to avoid repeated prompts
    private var hasPromptedForPermissions = false

    init() {
        Logger.info("WindowManager initialized", log: Logger.general)
    }

    /// Focus window for agent instance by PID
    /// Task: T042-T046 - window switching via NSRunningApplication + AppleScript
    ///
    /// - Parameters:
    ///   - pid: Process ID of the agent instance
    ///   - cwd: Optional working directory path (used to identify specific terminal window)
    /// - Returns: Result indicating success or failure with specific error
    ///
    /// Handles both GUI applications and CLI processes (running in Terminal)
    /// Requirement: SC-002 (<1s latency from mobile tap to window focus)
    func focusWindow(pid: pid_t, cwd: String? = nil) -> Result<Void, WindowManagerError> {
        // Task: T046 - check accessibility permissions
        if !checkAccessibilityPermissions() {
            Logger.error("Accessibility permissions not granted", log: Logger.general)
            return .failure(.accessibilityPermissionsRequired)
        }

        Logger.info("Attempting to focus window for PID \(pid), cwd: \(cwd ?? "none")", log: Logger.general)

        // Check if this is a GUI application (in NSRunningApplication list)
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
            // GUI application - use NSRunningApplication
            NSLog("🟢 Found GUI app for PID \(pid): \(app.localizedName ?? "unknown")")

            let success = app.activate(options: [.activateIgnoringOtherApps])
            if success {
                NSLog("✅ Successfully activated GUI app")
                Logger.info("Successfully focused window for PID \(pid)", log: Logger.general)
                return .success(())
            } else {
                NSLog("⚠️ GUI app activate() failed, trying AppleScript fallback")
                return focusWindowViaAppleScript(pid: pid)
            }
        } else {
            // Not a GUI app - likely a CLI process running in Terminal
            NSLog("🔵 PID \(pid) is not a GUI app, attempting Terminal focus with cwd: \(cwd ?? "none")")
            return focusTerminalForProcess(pid: pid, cwd: cwd)
        }
    }

    /// Focus Terminal window for a CLI process
    /// Used when the process is not a GUI application (e.g., `claude` in Terminal)
    /// Identifies the SPECIFIC terminal window running this process by matching cwd in window title
    private func focusTerminalForProcess(pid: pid_t, cwd: String? = nil) -> Result<Void, WindowManagerError> {
        NSLog("🔍 Searching for terminal emulator running PID \(pid)")

        // Walk up the process tree to find the terminal emulator
        let terminalPID = findTerminalEmulatorPID(for: pid)

        if terminalPID == 0 {
            NSLog("❌ Could not find terminal emulator in process tree")
            return focusWindowViaAppleScript(pid: pid)
        }

        NSLog("🟢 Found terminal emulator at PID \(terminalPID)")

        // Try to activate the terminal emulator by its PID
        let runningApps = NSWorkspace.shared.runningApplications
        if let terminal = runningApps.first(where: { $0.processIdentifier == terminalPID }) {
            let terminalName = terminal.localizedName ?? terminal.bundleIdentifier ?? "Unknown"
            let bundleId = terminal.bundleIdentifier ?? ""
            NSLog("🟢 Found terminal: \(terminalName) (bundle: \(bundleId))")

            // Try to focus specific window by cwd if available
            if let cwd = cwd, !cwd.isEmpty {
                let cwdResult = focusTerminalWindowByCwd(appName: terminalName, bundleId: bundleId, cwd: cwd)
                if case .success = cwdResult {
                    return cwdResult
                }
                NSLog("⚠️ Could not focus by cwd, falling back to app activation")
            }

            // Fallback: just activate the terminal app
            let success = terminal.activate(options: [.activateIgnoringOtherApps])
            if success {
                NSLog("✅ Successfully activated terminal emulator")
                Logger.info("Successfully focused terminal '\(terminalName)' for CLI process PID \(pid)", log: Logger.general)
                return .success(())
            } else {
                NSLog("⚠️ Terminal activation returned false")
            }
        }

        // Fallback: Try AppleScript
        NSLog("⚠️ Could not activate terminal via NSRunningApplication, trying AppleScript")
        return focusWindowViaAppleScript(pid: terminalPID)
    }

    /// Focus specific terminal window by matching cwd in window title
    /// Uses AppleScript to find and raise the window whose title contains the working directory
    private func focusTerminalWindowByCwd(appName: String, bundleId: String, cwd: String) -> Result<Void, WindowManagerError> {
        // Extract directory name for matching (e.g., "agent-deck" from "/Users/foo/dev/agent-deck")
        let dirName = (cwd as NSString).lastPathComponent
        NSLog("🔍 Looking for window with '\(dirName)' in title (full cwd: \(cwd))")

        // Build AppleScript to find and focus window by title
        let script: String

        switch bundleId {
        case "com.mitchellh.ghostty":
            // Ghostty: use System Events since Ghostty doesn't have native AppleScript support
            script = """
            tell application "Ghostty" to activate
            tell application "System Events"
                tell process "Ghostty"
                    set windowList to every window
                    repeat with w in windowList
                        if name of w contains "\(dirName)" then
                            perform action "AXRaise" of w
                            return "focused"
                        end if
                    end repeat
                end tell
            end tell
            return "not found"
            """
        case "com.apple.Terminal":
            script = """
            tell application "Terminal"
                activate
                set windowList to every window
                repeat with w in windowList
                    if name of w contains "\(dirName)" then
                        set frontmost of w to true
                        set index of w to 1
                        return "focused"
                    end if
                end repeat
            end tell
            return "not found"
            """
        case "com.googlecode.iterm2":
            script = """
            tell application "iTerm"
                activate
                set windowList to every window
                repeat with w in windowList
                    if name of w contains "\(dirName)" then
                        select w
                        return "focused"
                    end if
                end repeat
            end tell
            return "not found"
            """
        default:
            // Generic approach: just activate by app name
            NSLog("⚠️ No specific handler for \(bundleId), using generic activation")
            return .failure(.windowNotFound)
        }

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                NSLog("❌ AppleScript error: \(errorMessage)")
                return .failure(.applescriptError(errorMessage))
            }

            let resultString = result.stringValue ?? ""
            if resultString == "focused" {
                NSLog("✅ Successfully focused window containing '\(dirName)'")
                return .success(())
            } else {
                NSLog("⚠️ No window found containing '\(dirName)'")
                return .failure(.windowNotFound)
            }
        }

        return .failure(.applescriptError("Failed to create AppleScript"))
    }

    /// Walk up the process tree to find a terminal emulator or IDE
    /// Returns the PID of the parent application, or 0 if not found
    private func findTerminalEmulatorPID(for pid: pid_t) -> pid_t {
        let parentAppBundleIDs = [
            // Terminal Emulators
            "com.mitchellh.ghostty",        // Ghostty
            "com.apple.Terminal",           // Terminal.app
            "com.googlecode.iterm2",        // iTerm2
            "com.github.wez.wezterm",       // WezTerm
            "net.kovidgoyal.kitty",         // Kitty
            "org.alacritty",                // Alacritty

            // IDEs and Editors
            "com.microsoft.VSCode",         // Visual Studio Code
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.jetbrains.intellij",       // IntelliJ IDEA
            "com.jetbrains.pycharm",        // PyCharm
            "com.sublimetext.4",            // Sublime Text
            "com.panic.Nova"                // Nova
        ]

        var currentPID = pid
        var visited = Set<pid_t>() // Prevent infinite loops

        // Walk up the process tree (max 20 levels)
        for _ in 0..<20 {
            if currentPID <= 1 || visited.contains(currentPID) {
                break
            }
            visited.insert(currentPID)

            // Check if this PID is a known parent application
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == currentPID }) {
                if let bundleID = app.bundleIdentifier, parentAppBundleIDs.contains(bundleID) {
                    let name = app.localizedName ?? bundleID
                    NSLog("🎯 Found parent app in process tree: \(name) (PID \(currentPID))")
                    return currentPID
                }
            }

            // Move to parent process
            let parentPID = getParentProcessID(pid: currentPID)
            if parentPID == 0 || parentPID == currentPID {
                break
            }
            currentPID = parentPID
        }

        NSLog("❌ No parent terminal/IDE found in process tree for PID \(pid)")
        return 0
    }

    /// Focus window via AppleScript (fallback method)
    /// Note: Requires Automation permissions for System Events
    private func focusWindowViaAppleScript(pid: pid_t) -> Result<Void, WindowManagerError> {
        let script = """
        tell application "System Events"
            set frontmost of first process whose unix id is \(pid) to true
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                NSLog("❌ AppleScript error: \(errorMessage)")

                // Check if this is an automation permission error
                if errorMessage.contains("Not authorized") || errorMessage.contains("not allowed") {
                    Logger.error("Automation permissions required for System Events. User needs to grant permission in System Preferences > Privacy & Security > Automation.", log: Logger.general)
                    return .failure(.applescriptError("Agent Deck needs permission to control System Events. Please grant Automation permission in System Preferences > Privacy & Security > Automation."))
                }

                Logger.error("AppleScript error: \(errorMessage)", log: Logger.general)
                return .failure(.applescriptError(errorMessage))
            }

            NSLog("✅ AppleScript succeeded")
            Logger.info("Successfully focused window for PID \(pid) via AppleScript", log: Logger.general)
            return .success(())
        } else {
            Logger.error("Failed to create NSAppleScript object", log: Logger.general)
            return .failure(.applescriptError("Failed to initialize AppleScript"))
        }
    }

    /// Get parent process ID for a given PID
    /// Used to find the terminal emulator running a CLI process
    private func getParentProcessID(pid: pid_t) -> pid_t {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        let result = sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)

        if result == 0 {
            return kinfo.kp_eproc.e_ppid
        }

        return 0 // Failed to get parent PID
    }

    /// Check if accessibility permissions are granted
    /// Task: T046 - check for accessibility permissions before first switch
    ///
    /// - Returns: true if permissions granted, false otherwise
    private func checkAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessibilityEnabled {
            Logger.warning("Accessibility permissions not granted - user needs to enable in System Preferences", log: Logger.general)
        }

        return accessibilityEnabled
    }

    /// Prompt user to grant accessibility permissions (Task: T076-T077)
    /// Shows macOS system dialog for accessibility permissions
    ///
    /// Note: This method triggers the system permission dialog
    /// User must manually navigate to System Preferences to grant permission
    func promptForAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options)

        hasPromptedForPermissions = true
        Logger.info("Prompted user for accessibility permissions", log: Logger.general)
    }

    /// Check accessibility permissions with user-friendly error message
    /// Returns true if granted, false if denied (and shows helpful message)
    func checkAccessibilityWithFeedback() -> Bool {
        if checkAccessibilityPermissions() {
            return true
        }

        // Only prompt once per session to avoid annoyance
        if !hasPromptedForPermissions {
            Logger.warning("Accessibility permissions required but not granted", log: Logger.general)

            // Show user-friendly alert
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = """
                Window switching requires Accessibility permissions.

                To enable:
                1. Open System Settings
                2. Go to Privacy & Security > Accessibility
                3. Enable "Agent Deck"
                4. Try again

                This permission allows Agent Deck to bring windows to the front.
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.promptForAccessibilityPermissions()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            hasPromptedForPermissions = true
        }

        return false
    }

    /// Reset permission prompt state (useful after user grants permissions)
    func resetPermissionPromptState() {
        hasPromptedForPermissions = false
        Logger.info("Reset permission prompt state", log: Logger.general)
    }

    /// Check if a process with the given PID exists
    ///
    /// - Parameter pid: Process ID to check
    /// - Returns: true if process exists, false otherwise
    func processExists(pid: pid_t) -> Bool {
        // Use kill with signal 0 to check if process exists
        // Signal 0 doesn't send a signal but still performs error checking
        let result = kill(pid, 0)
        return result == 0
    }
}
