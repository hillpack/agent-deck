//
//  SubagentInfo.swift
//  Agent-Deck
//
//  Created by Agent Deck Team
//

import Foundation

/// Represents a subagent task spawned by the main agent
/// Used to display active parallel tasks in the UI
/// Fields match TypeScript shared-types/src/agent.ts SubagentInfo interface
struct SubagentInfo: Identifiable, Codable, Equatable {
    /// Unique identifier for this subagent (for Identifiable protocol)
    var id: String { agentId }

    /// Agent ID string (matches TypeScript "agentId")
    let agentId: String

    /// Subagent type: "Explore", "general-purpose", "Plan", etc.
    let type: String

    /// Human-readable description of what this subagent is doing
    /// Example: "Fix QR code port passing", "Search documentation for Convex patterns"
    let description: String

    /// Initialize a new subagent info
    init(agentId: String = UUID().uuidString,
         type: String,
         description: String) {
        self.agentId = agentId
        self.type = type
        self.description = description
    }

    /// Create dictionary representation for WebSocket messaging
    /// Matches TypeScript SubagentInfo interface exactly
    func toDictionary() -> [String: Any] {
        return [
            "agentId": agentId,
            "type": type,
            "description": description
        ]
    }
}
