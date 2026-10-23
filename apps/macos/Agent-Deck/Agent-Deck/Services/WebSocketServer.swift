//
//  WebSocketServer.swift
//  Agent-Deck
//
//  WebSocket server for real-time communication with PWA mobile clients
//  Spec: tasks.md T024-T028, contracts/websocket-protocol.md
//

import Foundation
import Network
import CryptoKit
import Combine

/// WebSocket server managing connections from mobile PWA clients
class WebSocketServer: ObservableObject {
    /// List of active WebSocket connections (after handshake)
    @Published var connections: [WebSocketConnection] = []

    /// Pending connections during handshake (must retain to prevent deallocation)
    private var pendingConnections: [NWConnection] = []

    /// Network listener
    private var listener: NWListener?

    /// Server port
    private var port: UInt16

    /// Reference to ProcessMonitor for broadcasting updates
    weak var processMonitor: ProcessMonitor?

    /// WindowManager for handling focus commands (assigned by AppDelegate)
    var windowManager: WindowManager?

    init(port: UInt16 = 3000) {
        self.port = port
        Logger.info("WebSocketServer initialized on port \(port)", log: Logger.network)
    }

    /// Start WebSocket server
    /// Task: T024 - implement WebSocketServer using Network.framework
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        // Bind to all interfaces (0.0.0.0) for local network access
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        guard let listener = listener else {
            NSLog("❌ WebSocket listener creation failed")
            throw NSError(domain: "AgentDeck", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create WebSocket listener"])
        }

        listener.newConnectionHandler = { [weak self] connection in
            // CRITICAL: Must retain connection IMMEDIATELY to prevent release
            guard let self = self else {
                NSLog("❌ WebSocketServer: self is nil in newConnectionHandler")
                return
            }
            // Store and start connection synchronously in the handler
            self.pendingConnections.append(connection)
            NSLog("🔌 New connection received (now \(self.pendingConnections.count) pending)")

            // Create a dedicated queue for this connection
            let connectionQueue = DispatchQueue(label: "com.agentdeck.ws.connection")

            // Set up state handler before starting
            connection.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleConnectionState(connection, state: state)
                }
            }

            // Start connection immediately - this "accepts" the server connection
            connection.start(queue: connectionQueue)
            NSLog("🔌 Connection started on dedicated queue")
        }

        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                NSLog("🔌 WebSocket server READY on port \(self.port)")
                Logger.info("WebSocket server listening on port \(self.port)", log: Logger.network)
            case .failed(let error):
                NSLog("❌ WebSocket server FAILED: \(error.localizedDescription)")
                Logger.error("WebSocket server failed: \(error.localizedDescription)", log: Logger.network)
            case .waiting(let error):
                NSLog("⏳ WebSocket server WAITING: \(error)")
            case .cancelled:
                NSLog("🛑 WebSocket server CANCELLED")
                Logger.info("WebSocket server cancelled", log: Logger.network)
            default:
                NSLog("❓ WebSocket server state: \(state)")
            }
        }

        listener.start(queue: .main)
    }

    /// Stop WebSocket server
    func stop() {
        listener?.cancel()
        // Cancel all pending connections
        for connection in pendingConnections {
            connection.cancel()
        }
        pendingConnections.removeAll()
        connections.removeAll()
        Logger.info("WebSocket server stopped", log: Logger.network)
    }

    /// Setup connection handlers and start the connection
    /// Called after connection is already stored in pendingConnections
    /// Task: T025 - WebSocket handshake
    private func setupConnectionHandlers(_ nwConnection: NWConnection) {
        nwConnection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                NSLog("🔌 Connection ready, starting handshake")
                self?.performWebSocketHandshake(nwConnection)
            case .failed(let error):
                NSLog("❌ Connection failed: \(error.localizedDescription)")
                Logger.error("Connection failed: \(error.localizedDescription)", log: Logger.network)
                self?.removePendingConnection(nwConnection)
            case .cancelled:
                NSLog("🔌 Connection cancelled")
                self?.removePendingConnection(nwConnection)
                self?.removeConnection(nwConnection)
            default:
                break
            }
        }

        // Start connection AFTER setting up handlers
        // Use global queue to avoid potential deadlock on main queue
        let connectionQueue = DispatchQueue(label: "com.agentdeck.connection.\(UUID().uuidString)")
        nwConnection.start(queue: connectionQueue)
    }

    /// Remove connection from pending list
    private func removePendingConnection(_ connection: NWConnection) {
        pendingConnections.removeAll { $0 === connection }
    }

    /// Handle connection state changes
    /// Called from stateUpdateHandler on main queue
    private func handleConnectionState(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .setup:
            NSLog("🔌 Connection state: setup")
        case .preparing:
            NSLog("🔌 Connection state: preparing")
        case .ready:
            NSLog("🔌 Connection state: READY - starting handshake")
            performWebSocketHandshake(connection)
        case .failed(let error):
            NSLog("❌ Connection state: FAILED - \(error.localizedDescription)")
            Logger.error("Connection failed: \(error.localizedDescription)", log: Logger.network)
            removePendingConnection(connection)
        case .cancelled:
            NSLog("🔌 Connection state: CANCELLED")
            removePendingConnection(connection)
            removeConnection(connection)
        case .waiting(let error):
            NSLog("⏳ Connection state: waiting - \(error.localizedDescription)")
        @unknown default:
            NSLog("❓ Connection state: unknown")
        }
    }

    /// Perform WebSocket handshake
    /// Task: T025 - implement WebSocket handshake per RFC 6455
    private func performWebSocketHandshake(_ connection: NWConnection) {
        NSLog("🔌 performWebSocketHandshake called, requesting data...")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            NSLog("🔌 Handshake receive callback triggered")
            if let error = error {
                NSLog("❌ Handshake receive error: \(error.localizedDescription)")
                Logger.error("Handshake receive error: \(error.localizedDescription)", log: Logger.network)
                self?.removePendingConnection(connection)
                return
            }

            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                NSLog("❌ Invalid handshake data - no data or not UTF-8")
                Logger.error("Invalid handshake data", log: Logger.network)
                self?.removePendingConnection(connection)
                return
            }
            NSLog("🔌 Received handshake request (\(data.count) bytes)")

            // Parse WebSocket key from request
            guard let wsKey = self?.extractWebSocketKey(from: request) else {
                NSLog("❌ Missing Sec-WebSocket-Key in request: \(request.prefix(200))")
                Logger.error("Missing Sec-WebSocket-Key in handshake", log: Logger.network)
                self?.removePendingConnection(connection)
                return
            }
            NSLog("🔌 Found WebSocket key: \(wsKey)")

            // Generate accept key (RFC 6455)
            let acceptKey = self?.generateAcceptKey(from: wsKey) ?? ""

            // Send handshake response
            let response = """
            HTTP/1.1 101 Switching Protocols\r
            Upgrade: websocket\r
            Connection: Upgrade\r
            Sec-WebSocket-Accept: \(acceptKey)\r
            \r

            """

            let responseData = response.data(using: .utf8)!
            connection.send(content: responseData, completion: .contentProcessed({ error in
                if let error = error {
                    Logger.error("Handshake send error: \(error.localizedDescription)", log: Logger.network)
                } else {
                    Logger.info("WebSocket handshake completed", log: Logger.network)
                    self?.completeConnection(connection)
                }
            }))
        }
    }

    /// Extract Sec-WebSocket-Key from HTTP request
    private func extractWebSocketKey(from request: String) -> String? {
        let lines = request.split(separator: "\r\n")
        for line in lines {
            if line.lowercased().hasPrefix("sec-websocket-key:") {
                let key = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                return key
            }
        }
        return nil
    }

    /// Generate Sec-WebSocket-Accept key per RFC 6455
    private func generateAcceptKey(from key: String) -> String {
        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = key + magicString
        let hash = SHA1.hash(data: combined.data(using: .utf8)!)
        return Data(hash).base64EncodedString()
    }

    /// Complete connection after handshake
    /// Task: T026 - send initial_state on connect
    private func completeConnection(_ nwConnection: NWConnection) {
        // Move from pending to active connections
        removePendingConnection(nwConnection)
        NSLog("🔌 Handshake complete, promoting to active connection")

        let wsConnection = WebSocketConnection(
            id: UUID(),
            connection: nwConnection,
            remoteAddress: "unknown" // TODO: Extract from connection
        )

        connections.append(wsConnection)

        // Send initial_state message (T026)
        sendInitialState(to: wsConnection)

        // Start receiving messages
        receiveMessages(from: wsConnection)

        Logger.info("Client connected: \(wsConnection.id)", log: Logger.network)
    }

    /// Send connected message to newly connected client
    /// Matches TypeScript shared-types/src/websocket.ts ConnectedMessage
    /// Task: T026 - broadcast initial state
    private func sendInitialState(to connection: WebSocketConnection) {
        let message: [String: Any] = [
            "type": "connected",  // TypeScript expects "connected", not "initial_state"
            "serverVersion": "1.0.0"
            // TODO Phase 5: Add customActions array when implemented
        ]

        sendMessage(message, to: connection)

        // Follow up immediately with current state
        guard let instances = processMonitor?.instances else { return }

        let stateMessage: [String: Any] = [
            "type": "update",
            "instances": instances.map { $0.toDictionary() }
        ]

        sendMessage(stateMessage, to: connection)
    }

    /// Broadcast update message to all connected clients
    /// Task: T027 - broadcast update on status change
    /// Sends full instances array to match TypeScript StatusUpdateMessage type
    func broadcastUpdate(instance: AgentInstance) {
        // Get all current instances and send full state
        // This matches the format expected by mobile app (StatusUpdateMessage)
        guard let instances = processMonitor?.instances else { return }

        let message: [String: Any] = [
            "type": "update",
            "instances": instances.map { $0.toDictionary() }
        ]

        broadcast(message)
    }

    /// Broadcast instance_added message
    /// Task: T028 - broadcast instance_added
    /// Now sends full instances array as 'update' message for mobile app compatibility
    func broadcastInstanceAdded(instance: AgentInstance) {
        // Send full instances array - mobile app only handles 'update' type
        guard let instances = processMonitor?.instances else { return }

        let message: [String: Any] = [
            "type": "update",
            "instances": instances.map { $0.toDictionary() }
        ]

        broadcast(message)
    }

    /// Broadcast instance_removed message
    /// Task: T028 - broadcast instance_removed
    /// Now sends full instances array as 'update' message for mobile app compatibility
    func broadcastInstanceRemoved(instanceId: UUID, reason: String = "process_terminated") {
        // Send full instances array - mobile app only handles 'update' type
        guard let instances = processMonitor?.instances else { return }

        let message: [String: Any] = [
            "type": "update",
            "instances": instances.map { $0.toDictionary() }
        ]

        broadcast(message)
    }

    /// Broadcast message to all connected clients
    func broadcastMessage(_ message: [String: Any]) {
        for connection in connections {
            sendMessage(message, to: connection)
        }
    }

    /// Broadcast message to all connected clients (convenience wrapper)
    private func broadcast(_ message: [String: Any]) {
        broadcastMessage(message)
    }

    /// Send message to specific connection
    private func sendMessage(_ message: [String: Any], to connection: WebSocketConnection) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.error("Failed to serialize message", log: Logger.network)
            return
        }

        // Encode as WebSocket text frame
        let frame = encodeTextFrame(jsonString)
        connection.connection.send(content: frame, completion: .contentProcessed({ error in
            if let error = error {
                Logger.error("Send error: \(error.localizedDescription)", log: Logger.network)
            }
        }))
    }

    /// Encode string as WebSocket text frame (RFC 6455)
    private func encodeTextFrame(_ text: String) -> Data {
        let payload = text.data(using: .utf8)!
        var frame = Data()

        // FIN bit + opcode 0x1 (text frame)
        frame.append(0x81)

        // Payload length
        let length = payload.count
        if length < 126 {
            frame.append(UInt8(length))
        } else if length < 65536 {
            frame.append(126)
            frame.append(UInt8(length >> 8))
            frame.append(UInt8(length & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((length >> (i * 8)) & 0xFF))
            }
        }

        // Payload
        frame.append(payload)

        return frame
    }

    /// Receive messages from connection
    private func receiveMessages(from connection: WebSocketConnection) {
        connection.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let error = error {
                Logger.error("Receive error: \(error.localizedDescription)", log: Logger.network)
                return
            }

            if let data = data {
                self?.handleMessage(data, from: connection)
            }

            // Continue receiving
            self?.receiveMessages(from: connection)
        }
    }

    /// Handle received WebSocket message
    private func handleMessage(_ data: Data, from connection: WebSocketConnection) {
        NSLog("🟡 handleMessage called with \(data.count) bytes")
        // Decode WebSocket frame (simplified - assumes single frame)
        guard data.count >= 2 else {
            NSLog("❌ Data too short: \(data.count) bytes")
            return
        }

        let masked = (data[1] & 0x80) != 0
        var payloadLength = Int(data[1] & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard data.count >= 4 else {
                NSLog("❌ Data too short for 126 length: \(data.count) bytes")
                return
            }
            payloadLength = Int(data[2]) << 8 | Int(data[3])
            offset = 4
        } else if payloadLength == 127 {
            guard data.count >= 10 else {
                NSLog("❌ Data too short for 127 length: \(data.count) bytes")
                return
            }
            // Extended payload length (8 bytes)
            offset = 10
        }

        if masked {
            guard data.count >= offset + 4 else {
                NSLog("❌ Data too short for masking key at offset \(offset): \(data.count) bytes")
                return
            }
            // Convert masking key slice to array for safe indexing
            let maskingKeySlice = data[offset..<offset+4]
            let maskingKey = Array(maskingKeySlice)
            offset += 4

            var unmaskedPayload = Data()
            let payloadData = data[offset...]
            for (i, byte) in payloadData.enumerated() {
                unmaskedPayload.append(byte ^ maskingKey[i % 4])
            }

            if let message = String(data: unmaskedPayload, encoding: .utf8) {
                NSLog("🔵 Decoded message: \(message)")
                processClientMessage(message, from: connection)
            } else {
                NSLog("❌ Failed to decode message as UTF-8")
            }
        } else {
            let payload = data[offset...]
            if let message = String(data: payload, encoding: .utf8) {
                processClientMessage(message, from: connection)
            }
        }
    }

    /// Process message from client
    private func processClientMessage(_ message: String, from connection: WebSocketConnection) {
        NSLog("🔵 processClientMessage called with: \(message)")

        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            NSLog("❌ Invalid message format: \(message)")
            Logger.error("Invalid message format", log: Logger.network)
            return
        }

        NSLog("✅ Received message type: \(type)")
        Logger.info("Received message type: \(type)", log: Logger.network)

        switch type {
        case "ping":
            sendPong(to: connection)
        case "focus":
            // Task: T047-T050 - handle focus message
            handleFocusMessage(json, from: connection)
        default:
            Logger.warning("Unknown message type: \(type)", log: Logger.network)
        }
    }

    /// Handle focus message from client
    /// Tasks: T047-T050 - receive instanceId, call WindowManager, send success/failure
    private func handleFocusMessage(_ json: [String: Any], from connection: WebSocketConnection) {
        // Task: T047 - parse incoming JSON to extract instanceId
        guard let instanceIdString = json["instanceId"] as? String,
              let instanceId = UUID(uuidString: instanceIdString) else {
            Logger.error("Invalid or missing instanceId in focus message", log: Logger.network)
            sendErrorMessage(to: connection, error: "missing_required_field", message: "instanceId is required")
            return
        }

        Logger.info("Focus request for instance: \(instanceId)", log: Logger.network)

        // Find instance in ProcessMonitor
        guard let instance = processMonitor?.instances.first(where: { $0.id == instanceId }) else {
            Logger.error("Instance not found: \(instanceId)", log: Logger.network)
            // Task: T050 - send focus_failure for instance not found
            sendFocusFailure(instanceId: instanceId, error: "instance_not_found", message: "Instance no longer exists", to: connection)
            return
        }

        // Task: T048 - call WindowManager.focusWindow
        guard let windowManager = windowManager else {
            Logger.error("WindowManager not initialized", log: Logger.network)
            sendFocusFailure(instanceId: instanceId, error: "internal_error", message: "Window manager not available", to: connection)
            return
        }

        let result = windowManager.focusWindow(pid: instance.pid, cwd: instance.workingDirectory)

        // Tasks: T049-T050 - send success or failure within 1 second
        switch result {
        case .success:
            // Task: T049 - send focus_success
            sendFocusSuccess(instanceId: instanceId, to: connection)
            Logger.info("Window focused successfully for instance: \(instanceId)", log: Logger.network)

        case .failure(let error):
            // Task: T050 - send focus_failure with error code and actionable message
            sendFocusFailure(instanceId: instanceId, error: error.errorCode, message: error.localizedDescription, to: connection)
            Logger.error("Window focus failed for instance \(instanceId): \(error.localizedDescription)", log: Logger.network)
        }
    }

    /// Send focus_success message to client
    /// Task: T049 - send within 1 second of receiving focus command
    private func sendFocusSuccess(instanceId: UUID, to connection: WebSocketConnection) {
        let message: [String: Any] = [
            "type": "focus_success",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "instanceId": instanceId.uuidString
        ]
        sendMessage(message, to: connection)
    }

    /// Send focus_failure message to client
    /// Task: T050 - send with error code and actionable message
    private func sendFocusFailure(instanceId: UUID, error: String, message: String, to connection: WebSocketConnection) {
        let responseMessage: [String: Any] = [
            "type": "focus_failure",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "instanceId": instanceId.uuidString,
            "error": error,
            "message": message
        ]
        sendMessage(responseMessage, to: connection)
    }

    /// Send error message to client
    private func sendErrorMessage(to connection: WebSocketConnection, error: String, message: String) {
        let errorMessage: [String: Any] = [
            "type": "error",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "error": error,
            "message": message
        ]
        sendMessage(errorMessage, to: connection)
    }

    /// Send pong response
    private func sendPong(to connection: WebSocketConnection) {
        let message: [String: Any] = [
            "type": "pong",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        sendMessage(message, to: connection)
    }

    /// Remove connection from list
    private func removeConnection(_ nwConnection: NWConnection) {
        connections.removeAll { $0.connection === nwConnection }
        Logger.info("Client disconnected", log: Logger.network)
    }
}

/// WebSocket connection wrapper
/// Spec: data-model.md Entity 5
struct WebSocketConnection {
    let id: UUID
    let connection: NWConnection
    let remoteAddress: String
    let connectedAt: Date

    init(id: UUID, connection: NWConnection, remoteAddress: String) {
        self.id = id
        self.connection = connection
        self.remoteAddress = remoteAddress
        self.connectedAt = Date()
    }
}

/// SHA1 hash implementation for WebSocket handshake
/// Note: SHA1 used only for WebSocket protocol compliance (RFC 6455), not for security
private struct SHA1 {
    static func hash(data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}

// CommonCrypto import
import CommonCrypto
