//
//  ProcessMonitor.swift
//  Agent-Deck
//
//  ProcessMonitor service - polls running processes to detect AI coding agents
//  Spec: tasks.md T018-T023, plan.md ProcessMonitor section
//

import Foundation
import Combine
import AppKit

/// Service responsible for monitoring running AI coding agent processes
/// Polls every 2 seconds and detects Claude Code instances
/// Uses FSEvents to monitor transcript files for real-time task updates
class ProcessMonitor: ObservableObject {
    /// Published list of detected agent instances
    @Published var instances: [AgentInstance] = []

    /// Polling timer cancellable
    private var timerCancellable: AnyCancellable?

    /// Current configuration
    private var configuration: Configuration?

    /// Process name pattern for Claude Code
    private let claudeCodePattern = "claude.*code"

    /// Transcript watcher for real-time task updates
    private var transcriptWatcher: TranscriptWatcher?

    /// Transcript parser for extracting rich data from JSONL files
    private let transcriptParser = TranscriptParser()

    /// Mapping of session IDs to working directories
    /// Used to match transcript updates to PIDs
    private var sessionToWorkingDir: [String: String] = [:]

    /// Cache git branches by working directory (avoid re-running git on every poll)
    /// Key: working directory path, Value: (branch name, timestamp)
    private var branchCache: [String: (branch: String?, timestamp: Date)] = [:]

    /// Cache invalidation interval for git branch (60 seconds)
    private let branchCacheInterval: TimeInterval = 60.0

    /// Background queue for polling operations
    /// Prevents blocking the main thread during process detection and lsof/pgrep calls
    private let pollingQueue = DispatchQueue(label: "com.agentdeck.polling", qos: .utility)

    init() {
        Logger.info("ProcessMonitor initialized", log: Logger.monitoring)
    }

    /// Start monitoring processes with 2 second polling interval
    /// Optimized for low CPU usage
    func startMonitoring(configuration: Configuration) {
        self.configuration = configuration

        // Start transcript watcher for real-time task updates
        transcriptWatcher = TranscriptWatcher()
        transcriptWatcher?.onTranscriptUpdate = { [weak self] sessionId, taskText in
            // FSEvents callback runs on background queue, dispatch to main for UI updates
            DispatchQueue.main.async {
                self?.handleTranscriptUpdate(sessionId: sessionId, taskText: taskText)
            }
        }
        transcriptWatcher?.startWatching()

        // Poll every 2 seconds on background queue (prevents main thread blocking)
        timerCancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Execute polling on background queue to avoid blocking UI
                self?.pollingQueue.async {
                    self?.pollProcesses()
                }
            }

        Logger.info("ProcessMonitor started with 2s polling interval (background queue) + FSEvents transcript watching", log: Logger.monitoring)

        // Perform initial poll on background queue
        pollingQueue.async { [weak self] in
            self?.pollProcesses()
        }
    }

    /// Stop monitoring processes
    func stopMonitoring() {
        timerCancellable?.cancel()
        timerCancellable = nil
        transcriptWatcher?.stopWatching()
        transcriptWatcher = nil
        Logger.info("ProcessMonitor stopped", log: Logger.monitoring)
    }

    /// Poll running processes and update instances list
    /// Tasks: T020-T023
    /// BUGFIX: Detect both GUI apps (NSWorkspace) and CLI processes (ps command)
    private func pollProcesses() {
        var detectedInstances: [AgentInstance] = []

        // 1. Detect GUI applications via NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if isClaudeCodeProcess(app) {
                let pid = app.processIdentifier
                if let instance = createOrUpdateInstance(pid: pid, detectedInstances: &detectedInstances) {
                    detectedInstances.append(instance)
                }
            }
        }

        // 2. Detect CLI processes via ps command
        // This catches Claude Code instances running in Terminal
        let cliProcesses = detectCLIProcesses()
        for pid in cliProcesses {
            // Skip if already detected via NSWorkspace
            if detectedInstances.contains(where: { $0.pid == pid }) {
                continue
            }

            if let instance = createOrUpdateInstance(pid: pid, detectedInstances: &detectedInstances) {
                detectedInstances.append(instance)
            }
        }

        // Detect removed instances (T023)
        let removedInstances = instances.filter { existing in
            !detectedInstances.contains(where: { $0.pid == existing.pid })
        }

        for removed in removedInstances {
            Logger.info("Claude Code instance terminated: PID \(removed.pid)", log: Logger.monitoring)
        }

        // Update instances list (T022)
        // Must dispatch to main thread since instances is @Published
        DispatchQueue.main.async { [weak self] in
            self?.instances = detectedInstances
        }
    }

    /// Create or update an instance for the given PID
    /// Returns existing instance if found, or creates new one
    /// Now tries to parse transcript for rich data on new instances
    private func createOrUpdateInstance(pid: pid_t, detectedInstances: inout [AgentInstance]) -> AgentInstance? {
        let workingDir = getWorkingDirectory(pid: pid)
        let windowId = getWindowIdentifier(pid: pid)

        // Read current task from status line cache files
        let currentTask = readTaskFromCacheFiles(pid: pid, workingDir: workingDir)

        // Get git branch (with caching)
        let gitBranch = getGitBranch(workingDirectory: workingDir)

        // Try to parse transcript for rich data (for new instances)
        var transcriptData: TranscriptData?
        if instances.first(where: { $0.pid == pid }) == nil {
            // New instance - try to find and parse transcript
            transcriptData = findAndParseTranscript(workingDir: workingDir)
        }

        // Check if this instance already exists
        if var existingInstance = instances.first(where: { $0.pid == pid }) {
            // Check if working directory changed (invalidate branch cache)
            if workingDir != existingInstance.workingDirectory {
                branchCache.removeValue(forKey: existingInstance.workingDirectory)
                Logger.debug("Working directory changed for PID \(pid), invalidating branch cache", log: Logger.monitoring)
            }

            // Update task if we found one
            if let task = currentTask, task != existingInstance.currentTask {
                existingInstance.currentTask = task
                existingInstance.lastActivityTimestamp = Date()
                existingInstance.status = .working // Update status to working if we have a task
                Logger.info("Updated task for PID \(pid): \(task)", log: Logger.monitoring)
            }
            // BUGFIX: Removed automatic .done transition when task becomes nil
            // Status should only change to .done when transcript hasn't updated in 30s
            // and there are no in_progress todos (handled in handleTranscriptUpdate)

            // Update git branch if it changed (working directory changed or cache refreshed)
            if gitBranch != existingInstance.gitBranch {
                existingInstance.gitBranch = gitBranch
            }

            return existingInstance
        } else {
            // Create new instance
            let status: AgentStatus = currentTask != nil ? .working : .idle

            // Use transcript data if available, otherwise use basic detection
            let modelName = transcriptData?.modelName
            let activeSubagents = transcriptData?.activeSubagents ?? []
            let todos = transcriptData?.todos ?? []
            let taskFromTranscript = transcriptData?.currentTask
            let lastStatement = transcriptData?.lastStatement

            let newInstance = AgentInstance(
                pid: pid,
                agentType: "claude-code",
                workingDirectory: workingDir,
                status: status,
                currentTask: taskFromTranscript ?? currentTask,
                lastActivityTimestamp: Date(),
                windowIdentifier: windowId,
                gitBranch: gitBranch,
                modelName: modelName,
                activeSubagents: activeSubagents,
                todos: todos,
                lastStatement: lastStatement
            )
            Logger.info("New Claude Code instance detected: PID \(pid), CWD: \(workingDir), Branch: \(gitBranch ?? "none"), Task: \(currentTask ?? "none")", log: Logger.monitoring)
            return newInstance
        }
    }

    /// Detect Claude Code CLI processes using pgrep (much more efficient)
    /// Returns array of PIDs for detected processes
    /// Filters out Claude desktop app (Claude.app) helper processes and child processes
    /// BUGFIX: Each Claude instance spawns multiple processes (main + node + shells)
    /// We only want the main "claude" executable processes, not children
    private func detectCLIProcesses() -> [pid_t] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        // Use -fl to get both PID and full command line
        task.arguments = ["-ifl", "claude"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Discard stderr

        var pids: [pid_t] = []

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.split(separator: "\n") {
                    let parts = line.split(separator: " ", maxSplits: 1)
                    guard parts.count >= 2,
                          let pid = pid_t(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        continue
                    }

                    let commandLine = String(parts[1]).lowercased()

                    // Filter out Claude desktop app helper processes
                    if commandLine.contains("/applications/claude.app/") {
                        continue
                    }

                    // Filter out node processes (Zed external agents, etc.)
                    if commandLine.contains("node") {
                        continue
                    }

                    // Filter out shell wrappers (zsh/bash executing claude commands)
                    if commandLine.starts(with: "/bin/zsh") || commandLine.starts(with: "/bin/bash") {
                        continue
                    }

                    // Only accept processes that start with "claude " (the main executable)
                    // This filters out shell command output that contains "claude" in env vars
                    if !commandLine.starts(with: "claude ") {
                        continue
                    }

                    // BUGFIX: Filter out claude processes whose parent is a node process
                    // These are Zed external agent child processes, not real Claude Code instances
                    if isChildOfNodeProcess(pid: pid) {
                        continue
                    }

                    pids.append(pid)
                }
            }

            if !pids.isEmpty {
                Logger.info("Detected \(pids.count) Claude Code CLI process(es)", log: Logger.monitoring)
            }
        } catch {
            Logger.error("Failed to run pgrep: \(error.localizedDescription)", log: Logger.monitoring)
        }

        return pids
    }

    /// Check if application is a Claude Code process
    /// Task: T020 - filter by executable name pattern
    private func isClaudeCodeProcess(_ app: NSRunningApplication) -> Bool {
        guard let executableURL = app.executableURL else { return false }

        let executableName = executableURL.lastPathComponent.lowercased()
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        let executablePath = executableURL.path.lowercased()

        // Exclude Claude desktop app (com.anthropic.claude)
        if bundleId == "com.anthropic.claude" || executablePath.contains("/applications/claude.app/") {
            return false
        }

        // Match various Claude Code executable patterns
        // Patterns: "claude", "claude-code", "claude code", "Claude", etc.
        if executableName.contains("claude") {
            return true
        }

        // Check bundle identifier for additional validation
        if bundleId.contains("claude") && bundleId.contains("code") {
            return true
        }

        return false
    }

    /// Get git branch for working directory
    /// Returns branch name (e.g., "001-mvp") or nil if not a git repo
    /// Uses cache to avoid re-running git command on every poll (60s TTL)
    private func getGitBranch(workingDirectory: String) -> String? {
        // Ignore "Unknown" working directories
        guard workingDirectory != "Unknown" else {
            return nil
        }

        // Check cache first
        let now = Date()
        if let cached = branchCache[workingDirectory],
           now.timeIntervalSince(cached.timestamp) < branchCacheInterval {
            return cached.branch
        }

        // Run: git -C <workingDirectory> branch --show-current
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", workingDirectory, "branch", "--show-current"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Discard stderr (not a git repo, git not installed, etc.)

        var branch: String? = nil

        do {
            try task.run()
            task.waitUntilExit()

            // Only process output if git command succeeded
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        branch = trimmed
                        Logger.debug("Git branch for \(workingDirectory): \(trimmed)", log: Logger.monitoring)
                    }
                }
            } else {
                // Not a git repo or git not installed - log at debug level, not error
                Logger.debug("Not a git repository: \(workingDirectory)", log: Logger.monitoring)
            }
        } catch {
            // Git command failed (likely git not installed)
            Logger.debug("Git command failed for \(workingDirectory): \(error.localizedDescription)", log: Logger.monitoring)
        }

        // Cache result (even if nil, to avoid repeated failed git calls)
        branchCache[workingDirectory] = (branch: branch, timestamp: now)

        return branch
    }

    /// Get working directory for process
    /// Task: T021 - extract working directory via lsof
    private func getWorkingDirectory(pid: pid_t) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", "\(pid)", "-a", "-d", "cwd", "-F", "n"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Discard stderr

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse lsof output - format: "n/path/to/dir"
                for line in output.split(separator: "\n") {
                    if line.hasPrefix("n") {
                        let path = String(line.dropFirst())
                        if !path.isEmpty {
                            return path
                        }
                    }
                }
            }
        } catch {
            Logger.error("Failed to get working directory for PID \(pid): \(error.localizedDescription)", log: Logger.monitoring)
        }

        return "Unknown"
    }

    /// Get window identifier for process
    /// Task: T021 - extract window ID (optional in Phase 1-2)
    private func getWindowIdentifier(pid: pid_t) -> String? {
        // Window ID extraction via AppleScript or CGWindowList
        // For Phase 1-2, this is optional - return nil for now
        // Will be fully implemented in Phase 2 (User Story 2: Window Switching)
        return nil
    }

    /// Read task information from activity files written by Claude Code hooks
    /// Activity files are written by ~/.claude/agent-deck-monitor.py (hook script)
    /// Location: ~/.agentdeck/activity-{session_id}.json
    /// Matches instances by comparing working directory (cwd)
    private func readTaskFromCacheFiles(pid: pid_t, workingDir: String) -> String? {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentdeck")

        // Check if cache directory exists
        guard FileManager.default.fileExists(atPath: cacheDir.path) else {
            return nil
        }

        // Read all activity files
        do {
            let cacheFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)

            // Look for activity files matching this working directory
            for cacheFile in cacheFiles where cacheFile.lastPathComponent.hasPrefix("activity-") {
                guard let data = try? Data(contentsOf: cacheFile),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                // Extract activity data
                let cachedCwd = json["cwd"] as? String ?? ""
                let currentTask = json["current_task"] as? String

                // Match by working directory
                if cachedCwd == workingDir, let taskText = currentTask, !taskText.isEmpty {
                    Logger.info("Found task from hook for PID \(pid): \(taskText)", log: Logger.monitoring)
                    return taskText
                }
            }
        } catch {
            Logger.error("Failed to read activity directory: \(error.localizedDescription)", log: Logger.monitoring)
        }

        return nil
    }

    /// Extract current task from terminal window content using Accessibility API
    /// ⚠️ DEPRECATED: This method is no longer used. Use readTaskFromCacheFiles() instead.
    /// Reads visible text from terminal and parses for task information
    private func extractTaskFromTerminal(pid: pid_t) -> String? {
        // Find the terminal window for this PID
        guard let terminalApp = findTerminalApp(for: pid) else {
            return nil
        }

        // Get the focused/main window
        let appElement = AXUIElementCreateApplication(terminalApp.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            return nil
        }

        // Try to read text content from the first window
        for window in windows {
            if let taskText = readTerminalContent(from: window) {
                return taskText
            }
        }

        return nil
    }

    /// Find the terminal application running this PID
    private func findTerminalApp(for pid: pid_t) -> NSRunningApplication? {
        // Walk up the process tree to find terminal emulator
        var currentPID = pid
        let runningApps = NSWorkspace.shared.runningApplications

        for _ in 0..<20 {
            if currentPID <= 1 { break }

            // Check if this PID is a terminal app
            if let app = runningApps.first(where: { $0.processIdentifier == currentPID }),
               let bundleID = app.bundleIdentifier,
               isTerminalOrIDE(bundleID: bundleID) {
                return app
            }

            // Move to parent
            let parentPID = getParentProcessID(pid: currentPID)
            if parentPID == 0 || parentPID == currentPID { break }
            currentPID = parentPID
        }

        return nil
    }

    /// Check if bundle ID is a terminal or IDE
    private func isTerminalOrIDE(bundleID: String) -> Bool {
        let terminalBundleIDs = [
            "com.mitchellh.ghostty",
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.github.wez.wezterm",
            "net.kovidgoyal.kitty",
            "org.alacritty",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92", // Cursor
        ]
        return terminalBundleIDs.contains(bundleID)
    }

    /// Read terminal content and extract task text
    private func readTerminalContent(from window: AXUIElement) -> String? {
        // Try to get the text content from the window
        var valueRef: CFTypeRef?

        // First try to get the focused element within the window
        let focusResult = AXUIElementCopyAttributeValue(window, kAXFocusedUIElementAttribute as CFString, &valueRef)

        if focusResult == .success, let focusedElement = valueRef as! AXUIElement? {
            // Try to get the value (text content) from focused element
            var textRef: CFTypeRef?
            let textResult = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &textRef)

            if textResult == .success, let text = textRef as? String {
                return parseTaskFromText(text)
            }
        }

        // Fallback: Try to get description or title
        var descRef: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(window, kAXDescriptionAttribute as CFString, &descRef)

        if descResult == .success, let desc = descRef as? String {
            return parseTaskFromText(desc)
        }

        return nil
    }

    /// Parse task information from terminal text
    private func parseTaskFromText(_ text: String) -> String? {
        // Look for "Currently:" lines
        let lines = text.split(separator: "\n")

        for line in lines.reversed() { // Start from most recent
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Match "Currently:" pattern
            if trimmed.lowercased().hasPrefix("currently:") {
                let task = trimmed.dropFirst("currently:".count).trimmingCharacters(in: .whitespaces)
                if !task.isEmpty {
                    return String(task.prefix(200)) // Truncate to 200 chars
                }
            }

            // Also check for common Claude Code task indicators
            if trimmed.contains("Implementing") || trimmed.contains("Testing") ||
               trimmed.contains("Fixing") || trimmed.contains("Refactoring") {
                return String(trimmed.prefix(200))
            }
        }

        return nil
    }

    /// Get parent process ID (helper for terminal detection)
    private func getParentProcessID(pid: pid_t) -> pid_t {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        let result = sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)

        if result == 0 {
            return kinfo.kp_eproc.e_ppid
        }

        return 0
    }

    /// Check if a process is a child of a node process
    /// Used to filter out Zed external agent spawned claude processes
    /// Returns true if parent process name contains "node"
    private func isChildOfNodeProcess(pid: pid_t) -> Bool {
        let parentPID = getParentProcessID(pid: pid)
        if parentPID == 0 {
            return false
        }

        // Get parent process name using ps
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(parentPID)", "-o", "comm="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let processName = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // Check if parent is node, nodejs, or any node variant
                return processName.contains("node")
            }
        } catch {
            // If we can't determine parent, assume it's not a node child
            return false
        }

        return false
    }

    /// Update status for a specific instance
    /// Currently unused but available for future use (Phase 6: OutputParser integration)
    /// Thread-safe: Can be called from any thread
    func updateInstanceStatus(pid: pid_t, status: AgentStatus, currentTask: String? = nil) {
        // Ensure updates happen on main thread since instances is @Published
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let index = self.instances.firstIndex(where: { $0.pid == pid }) else {
                Logger.warning("Attempted to update status for unknown instance PID \(pid)", log: Logger.monitoring)
                return
            }

            self.instances[index].status = status
            self.instances[index].lastActivityTimestamp = Date()

            if let task = currentTask {
                // Truncate to 200 chars (data-model.md validation rule)
                self.instances[index].currentTask = String(task.prefix(200))
            }

            Logger.info("Updated instance PID \(pid): status=\(status.rawValue), task=\(currentTask ?? "nil")", log: Logger.monitoring)
        }
    }

    /// Handle real-time transcript update from FSEvents
    /// Maps session ID to working directory and updates matching instance
    /// Now uses TranscriptParser to extract rich data (modelName, subagents, todos)
    private func handleTranscriptUpdate(sessionId: String, taskText: String) {
        // Find the transcript file to extract working directory directly from it
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        do {
            let projectDirs = try FileManager.default.contentsOfDirectory(
                at: projectsDir,
                includingPropertiesForKeys: nil
            )

            // Find project directory containing this session ID
            for projectDir in projectDirs {
                let transcriptPath = projectDir.appendingPathComponent("\(sessionId).jsonl")
                if FileManager.default.fileExists(atPath: transcriptPath.path) {
                    // Parse full transcript with TranscriptParser (runs on background thread - already on correct queue)
                    guard let data = transcriptParser.parseTranscript(path: transcriptPath.path) else {
                        Logger.warning("Could not parse transcript: \(transcriptPath.path)", log: Logger.monitoring)
                        return
                    }

                    guard let workingDir = data.workingDirectory else {
                        Logger.warning("No working directory in transcript: \(transcriptPath.path)", log: Logger.monitoring)
                        return
                    }

                    Logger.info("Transcript cwd: \(workingDir), session: \(sessionId)", log: Logger.monitoring)

                    // BUGFIX: Use EXACT path matching only to prevent data mixing between instances
                    // Previously used fuzzy matching which caused data from one instance to show on another
                    // Match by session ID first (if available), then fall back to exact path match
                    if let index = instances.firstIndex(where: {
                        // Prefer session ID matching (most precise)
                        if let instanceSession = $0.sessionId {
                            return instanceSession == sessionId
                        }
                        // Fall back to exact working directory match
                        return $0.workingDirectory == workingDir
                    }) {
                        // Create updated instance with rich data (triggers @Published notification)
                        var updatedInstance = instances[index]

                        // Update transcript timestamp for stale detection
                        updatedInstance.lastTranscriptUpdate = Date()
                        updatedInstance.sessionId = sessionId

                        // Update basic fields
                        updatedInstance.currentTask = data.currentTask ?? String(taskText.prefix(200))
                        updatedInstance.lastActivityTimestamp = Date()

                        // BUGFIX: Smart status detection based on actual work state
                        // Don't always set to .working - check if there's actually work happening
                        let hasInProgressTodos = data.todos.contains { $0.status == "in_progress" }
                        let hasCurrentTask = data.currentTask != nil

                        if hasInProgressTodos || hasCurrentTask {
                            updatedInstance.status = .working
                        } else if !data.todos.isEmpty {
                            // Has todos but none in progress - idle
                            updatedInstance.status = .idle
                        } else {
                            // No todos, no task - keep existing status or set to idle
                            if updatedInstance.status == .working {
                                updatedInstance.status = .idle
                            }
                        }

                        // Update rich data fields
                        updatedInstance.modelName = data.modelName
                        updatedInstance.activeSubagents = data.activeSubagents
                        updatedInstance.todos = data.todos
                        updatedInstance.currentTaskDescription = data.todos.first(where: { $0.isInProgress })?.activeForm
                        updatedInstance.lastStatement = data.lastStatement

                        // Replace the instance (this triggers Combine @Published)
                        instances[index] = updatedInstance

                        Logger.info("✅ Real-time update for \(updatedInstance.workingDirectory): \(updatedInstance.currentTask ?? "no task"), model: \(updatedInstance.modelName ?? "unknown"), subagents: \(updatedInstance.activeSubagents.count), todos: \(updatedInstance.todos.count)", log: Logger.monitoring)
                    } else {
                        Logger.warning("No instance found for cwd: \(workingDir). Instances: \(instances.map { $0.workingDirectory })", log: Logger.monitoring)
                    }

                    return
                }
            }
        } catch {
            Logger.error("Failed to process transcript update: \(error.localizedDescription)", log: Logger.monitoring)
        }
    }

    /// Find and parse transcript for a given working directory
    /// Searches ~/.claude/projects for transcript matching working directory
    /// Returns parsed TranscriptData if found, nil otherwise
    private func findAndParseTranscript(workingDir: String) -> TranscriptData? {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard FileManager.default.fileExists(atPath: projectsDir.path) else {
            return nil
        }

        do {
            let projectDirs = try FileManager.default.contentsOfDirectory(
                at: projectsDir,
                includingPropertiesForKeys: nil
            )

            // Search for transcript matching this working directory
            for projectDir in projectDirs {
                let transcriptFiles = try FileManager.default.contentsOfDirectory(
                    at: projectDir,
                    includingPropertiesForKeys: nil
                )

                for transcriptFile in transcriptFiles where transcriptFile.pathExtension == "jsonl" {
                    // BUGFIX: Use EXACT path matching to prevent incorrect associations
                    // Parse transcript to check if working directory matches
                    if let data = transcriptParser.parseTranscript(path: transcriptFile.path),
                       let transcriptCwd = data.workingDirectory,
                       transcriptCwd == workingDir {
                        Logger.info("Found transcript for \(workingDir): \(transcriptFile.lastPathComponent)", log: Logger.monitoring)
                        return data
                    }
                }
            }
        } catch {
            Logger.error("Failed to search for transcript: \(error.localizedDescription)", log: Logger.monitoring)
        }

        return nil
    }

    /// Read working directory from transcript file
    /// Reads the cwd field from the most recent entry
    private func readCwdFromTranscript(path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Read last line to get most recent cwd
        let lines = content.split(separator: "\n")
        for line in lines.reversed().prefix(10) {  // Check last 10 lines
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let cwd = json["cwd"] as? String else {
                continue
            }
            return cwd
        }

        return nil
    }
}

