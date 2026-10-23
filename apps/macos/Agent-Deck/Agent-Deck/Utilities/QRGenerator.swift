//
//  QRGenerator.swift
//  Agent-Deck
//
//  QR code generation and network IP discovery for mobile setup
//  Spec: tasks.md T055-T057, T061
//

import Foundation
import CoreImage
import AppKit

/// Utility for generating QR codes and discovering local network information
/// Tasks: T055-T057 - QR generation, IP discovery, URL composition
enum QRGenerator {

    // MARK: - QR Code Generation

    /// Generate QR code image from string
    /// Task: T055 - implement QR code generation using CoreImage
    /// - Parameter string: String to encode (typically a URL)
    /// - Returns: NSImage containing QR code, or nil if generation failed
    static func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8) else {
            Logger.error("Failed to convert string to data for QR generation", log: Logger.general)
            return nil
        }

        // Create QR code filter
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            Logger.error("QR code filter not available", log: Logger.general)
            return nil
        }

        // Configure filter for high error correction
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else {
            Logger.error("Failed to generate QR code output image", log: Logger.general)
            return nil
        }

        // Scale up for better visibility on mobile devices
        // Task: T055 - scale 10x for readability from 12-18 inches
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        // Convert CIImage to NSImage
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        Logger.info("Generated QR code for: \(string)", log: Logger.general)
        return nsImage
    }

    // MARK: - Network Discovery

    /// Get local IP address on WiFi network
    /// Task: T056 - implement IP discovery using getifaddrs() filtering en0
    /// - Returns: IPv4 address string, or nil if not connected to WiFi
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        // Get network interfaces
        guard getifaddrs(&ifaddr) == 0 else {
            Logger.error("Failed to get network interfaces", log: Logger.network)
            return nil
        }

        defer {
            freeifaddrs(ifaddr)
        }

        // Iterate through interfaces
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            // Check address family (IPv4)
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }

            // Get interface name
            let name = String(cString: interface.ifa_name)

            // Filter for en0 (WiFi interface on macOS)
            // Also check en1 as backup (some Macs use en1 for WiFi)
            guard name == "en0" || name == "en1" else { continue }

            // Convert address to string
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            )

            let ipAddress = String(cString: hostname)

            // Prefer en0, but accept en1 if that's what we find
            if name == "en0" {
                address = ipAddress
                break
            } else if address == nil {
                address = ipAddress
            }
        }

        if let address = address {
            Logger.info("Discovered local IP: \(address)", log: Logger.network)
        } else {
            Logger.warning("No WiFi IP address found (not connected to WiFi?)", log: Logger.network)
        }

        return address
    }

    // MARK: - URL Generation

    /// Generate local network URL for mobile access (HTTP)
    /// Task: T057 - generate URL containing local IP and port
    /// - Parameter port: HTTP server port (default: 3000)
    /// - Returns: Complete URL string, or nil if no IP available
    static func generateLocalURL(port: UInt16 = 3000) -> String? {
        guard let ipAddress = getLocalIPAddress() else {
            return nil
        }

        return "http://\(ipAddress):\(port)"
    }

    /// Generate WebSocket URL for mobile app access
    /// - Parameter httpPort: HTTP server port (WebSocket runs on httpPort + 1)
    /// - Returns: WebSocket URL string, or nil if no IP available
    static func generateWebSocketURL(httpPort: UInt16 = 3000) -> String? {
        guard let ipAddress = getLocalIPAddress() else {
            return nil
        }
        // WebSocket server runs on HTTP port + 1
        let wsPort = httpPort + 1
        return "ws://\(ipAddress):\(wsPort)"
    }

    /// Generate QR code for local network access
    /// Convenience method combining URL generation and QR creation
    /// - Parameter port: HTTP server port (WebSocket runs on port + 1)
    /// - Returns: Tuple of (QR code image, URL string), or nil if generation failed
    /// Note: Generates WebSocket URL (ws://) for React Native mobile app compatibility
    static func generateMobileAccessQR(port: UInt16 = 3000) -> (image: NSImage, url: String)? {
        // Generate WebSocket URL for React Native mobile app
        guard let url = generateWebSocketURL(httpPort: port) else {
            Logger.error("Cannot generate QR: no local IP address", log: Logger.network)
            return nil
        }

        guard let qrImage = generateQRCode(from: url) else {
            Logger.error("Cannot generate QR: QR code creation failed", log: Logger.general)
            return nil
        }

        return (image: qrImage, url: url)
    }
}

// MARK: - Network Error Types

/// Errors related to network configuration and QR generation
/// Task: T061 - error handling for missing WiFi
enum NetworkError: LocalizedError {
    case noWiFiConnection
    case portAlreadyInUse(port: UInt16)
    case qrGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noWiFiConnection:
            return "Not connected to WiFi. Connect to WiFi to access Agent Deck from mobile."
        case .portAlreadyInUse(let port):
            return "Port \(port) is already in use. Change port in Settings."
        case .qrGenerationFailed:
            return "Failed to generate QR code. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noWiFiConnection:
            return "Connect your Mac to a WiFi network to enable mobile access."
        case .portAlreadyInUse:
            return "Close other applications using port 3000 or change the port in Agent Deck settings."
        case .qrGenerationFailed:
            return "Restart Agent Deck or check system logs for details."
        }
    }
}
