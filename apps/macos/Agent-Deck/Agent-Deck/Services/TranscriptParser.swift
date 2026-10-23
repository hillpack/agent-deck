//
//  TranscriptParser.swift
//  Agent-Deck
//
//  Rich transcript parser - extracts structured data from Claude Code JSONL transcripts
//  Parses: modelName, activeSubagents (Task tool), todos (TodoWrite), currentTask
//  Spec: tasks.md, data-model.md
//

import Foundation

// MARK: - Data Models

/// Complete parsed transcript data
/// Note: SubagentInfo and TodoItem are defined in Models/
struct TranscriptData: Equatable {
    var modelName: String?
    var activeSubagents: [SubagentInfo]
    var todos: [TodoItem]
    var currentTask: String?
    var workingDirectory: String?
    var lastStatement: String?  // Last text message from Claude (for display when idle)

    init(modelName: String? = nil,
         activeSubagents: [SubagentInfo] = [],
         todos: [TodoItem] = [],
         currentTask: String? = nil,
         workingDirectory: String? = nil,
         lastStatement: String? = nil) {
        self.modelName = modelName
        self.activeSubagents = activeSubagents
        self.todos = todos
        self.currentTask = currentTask
        self.workingDirectory = workingDirectory
        self.lastStatement = lastStatement
    }
}

/// Service for parsing Claude Code transcript JSONL files
class TranscriptParser {

    init() {
        Logger.info("TranscriptParser initialized", log: Logger.monitoring)
    }

    /// Parse entire transcript file and return extracted data
    /// - Parameter path: Absolute path to transcript.jsonl file
    /// - Returns: Parsed transcript data or nil if file cannot be read
    func parseTranscript(path: String) -> TranscriptData? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            Logger.error("Failed to read transcript file: \(path)", log: Logger.monitoring)
            return nil
        }

        var data = TranscriptData()

        // Extract model name (usually appears early in transcript)
        data.modelName = extractModelName(from: content)

        // Extract working directory (from "cwd" field)
        data.workingDirectory = extractWorkingDirectory(from: content)

        // Extract subagents from Task tool calls
        data.activeSubagents = extractSubagents(from: content)

        // Extract todos from TodoWrite tool calls
        data.todos = extractTodos(from: content)

        // Get current task (first in_progress todo)
        data.currentTask = getCurrentTask(from: data.todos)

        // Extract last statement from Claude (for idle display)
        data.lastStatement = extractLastStatement(from: content)

        return data
    }

    /// Parse model name from transcript
    /// Converts technical model IDs to friendly names
    /// - Parameter jsonl: JSONL content
    /// - Returns: Friendly model name or nil
    func extractModelName(from jsonl: String) -> String? {
        let lines = jsonl.split(separator: "\n")

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let model = message["model"] as? String else {
                continue
            }

            return convertModelToFriendlyName(model)
        }

        return nil
    }

    /// Extract working directory from transcript
    /// - Parameter jsonl: JSONL content
    /// - Returns: Working directory path or nil
    func extractWorkingDirectory(from jsonl: String) -> String? {
        let lines = jsonl.split(separator: "\n")

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cwd = json["cwd"] as? String else {
                continue
            }

            return cwd
        }

        return nil
    }

    /// Parse active subagents from tool_use blocks with name="Task"
    /// - Parameter jsonl: JSONL content
    /// - Returns: Array of SubagentInfo for ONLY active subagents (not yet completed)
    /// BUGFIX: Previously returned ALL subagents ever seen in transcript.
    /// Now tracks tool_use IDs and filters out subagents that have completed (have matching tool_result).
    func extractSubagents(from jsonl: String) -> [SubagentInfo] {
        var toolUseBlocks: [String: SubagentInfo] = [:]  // id -> subagent
        var completedToolIds: Set<String> = []
        let lines = jsonl.split(separator: "\n")

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                continue
            }

            // Process each content item
            for item in content {
                let itemType = item["type"] as? String

                // Track Task tool_use blocks (subagents starting)
                if itemType == "tool_use",
                   item["name"] as? String == "Task",
                   let toolUseId = item["id"] as? String,
                   let input = item["input"] as? [String: Any] {

                    let description = input["description"] as? String ?? "Unknown task"
                    let subagentType = input["subagent_type"] as? String ?? "general-purpose"

                    let subagent = SubagentInfo(
                        agentId: toolUseId,
                        type: subagentType,
                        description: description
                    )

                    toolUseBlocks[toolUseId] = subagent
                }

                // Track tool_result blocks (subagents completing)
                if itemType == "tool_result",
                   let toolUseId = item["tool_use_id"] as? String {
                    completedToolIds.insert(toolUseId)
                }
            }
        }

        // Return only uncompleted subagents
        let activeSubagents = toolUseBlocks.filter { !completedToolIds.contains($0.key) }.map { $0.value }

        return activeSubagents
    }

    /// Parse todos from TodoWrite tool calls
    /// - Parameter jsonl: JSONL content
    /// - Returns: Array of TodoItem from the LATEST TodoWrite only (excluding completed todos)
    /// BUGFIX: Previously merged todos from ALL TodoWrite calls, showing all todos ever seen.
    /// Now returns only the most recent TodoWrite (last one in transcript) and filters out completed todos.
    func extractTodos(from jsonl: String) -> [TodoItem] {
        let lines = jsonl.split(separator: "\n")

        // Iterate in REVERSE order to find the LATEST TodoWrite first
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                continue
            }

            // Check each content item for TodoWrite tool use
            for item in content {
                guard item["type"] as? String == "tool_use",
                      item["name"] as? String == "TodoWrite",
                      let input = item["input"] as? [String: Any],
                      let todos = input["todos"] as? [[String: Any]] else {
                    continue
                }

                // Found the latest TodoWrite - parse todos and filter out completed ones
                var activeTodos: [TodoItem] = []

                for todoDict in todos {
                    let content = todoDict["content"] as? String ?? ""
                    let status = todoDict["status"] as? String ?? "pending"
                    let activeForm = todoDict["activeForm"] as? String ?? content

                    // Skip completed todos
                    if status == "completed" {
                        continue
                    }

                    // Create TodoItem using existing model initializer
                    let todo = TodoItem(
                        content: content,
                        activeForm: activeForm,
                        status: status
                    )

                    activeTodos.append(todo)
                }

                // Return immediately - this is the latest TodoWrite
                return activeTodos
            }
        }

        // No TodoWrite found in transcript
        return []
    }

    /// Get current task (first in_progress todo)
    /// - Parameter todos: Array of TodoItem
    /// - Returns: Current task description or nil
    func getCurrentTask(from todos: [TodoItem]) -> String? {
        // Find first todo with status "in_progress"
        let inProgressTodo = todos.first { $0.status == "in_progress" }

        // Return activeForm for better display ("Creating..." vs "Create...")
        return inProgressTodo?.activeForm
    }

    /// Extract the last text statement from Claude (excluding tool calls)
    /// This is used to display what Claude last said when there's no active task
    /// - Parameter jsonl: JSONL content
    /// - Returns: Last text message from Claude, or nil if none found
    func extractLastStatement(from jsonl: String) -> String? {
        let lines = jsonl.split(separator: "\n")

        // Iterate in REVERSE to find the most recent assistant message
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let role = message["role"] as? String,
                  role == "assistant",
                  let content = message["content"] as? [[String: Any]] else {
                continue
            }

            // Extract text blocks (not tool_use or tool_result)
            var textParts: [String] = []

            for item in content {
                if let type = item["type"] as? String, type == "text",
                   let text = item["text"] as? String {
                    textParts.append(text)
                }
            }

            // Combine all text parts
            if !textParts.isEmpty {
                let combined = textParts.joined(separator: " ")
                let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)

                // Return last meaningful statement (truncate to 300 chars for display)
                if !trimmed.isEmpty {
                    return String(trimmed.prefix(300))
                }
            }
        }

        return nil
    }

    // MARK: - Private Helper Methods

    /// Convert technical model ID to friendly name
    /// - Parameter model: Raw model ID (e.g., "claude-sonnet-4-5-20250929")
    /// - Returns: Friendly name (e.g., "Sonnet 4.5")
    private func convertModelToFriendlyName(_ model: String) -> String {
        // Match common Claude model patterns
        if model.contains("sonnet") {
            if model.contains("4-5") || model.contains("4.5") {
                return "Sonnet 4.5"
            } else if model.contains("3-5") || model.contains("3.5") {
                return "Sonnet 3.5"
            } else if model.contains("3-7") || model.contains("3.7") {
                return "Sonnet 3.7"
            }
            return "Sonnet"
        } else if model.contains("opus") {
            return "Opus"
        } else if model.contains("haiku") {
            return "Haiku"
        }

        // Return original if no match
        return model
    }

}

// MARK: - Edge Case Handling & Safety

extension TranscriptParser {
    /// Parse transcript with comprehensive error handling
    /// - Parameter path: Absolute path to transcript file
    /// - Returns: TranscriptData (empty if parsing fails completely)
    func parseTranscriptSafe(path: String) -> TranscriptData {
        guard let data = parseTranscript(path: path) else {
            // Return empty data if file doesn't exist or is unreadable
            Logger.error("parseTranscriptSafe: Failed to parse, returning empty data", log: Logger.monitoring)
            return TranscriptData()
        }

        return data
    }

    /// Validate transcript file format
    /// - Parameter path: Absolute path to transcript file
    /// - Returns: True if file appears to be valid JSONL
    func isValidTranscript(path: String) -> Bool {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return false
        }

        let lines = content.split(separator: "\n")
        guard !lines.isEmpty else {
            return false
        }

        // Check if first line is valid JSON
        guard let firstLine = lines.first,
              let data = firstLine.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }

        return true
    }
}

// MARK: - Array Extension

extension Array where Element: Equatable {
    /// Remove duplicates from array while maintaining order
    func removingDuplicates() -> [Element] {
        var result: [Element] = []
        for element in self {
            if !result.contains(element) {
                result.append(element)
            }
        }
        return result
    }
}
