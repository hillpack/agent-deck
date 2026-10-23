//
//  QRCodeView.swift
//  Agent-Deck
//
//  SwiftUI view for displaying QR code and mobile setup instructions
//  Spec: tasks.md T058-T060
//

import SwiftUI
import AppKit

/// View displaying QR code for mobile PWA access
/// Tasks: T058-T060 - QR display, URL text, copy functionality
struct QRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: NSImage?
    @State private var localURL: String?
    @State private var errorMessage: String?
    @State private var showCopiedFeedback = false

    let port: UInt16

    init(port: UInt16 = 3000) {
        self.port = port
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with close button
            headerView

            Divider()

            // Main content (scrollable if needed)
            ScrollView {
                if let error = errorMessage {
                    errorView(message: error)
                } else if let qrImage = qrImage, let url = localURL {
                    successView(qrImage: qrImage, url: url)
                } else {
                    loadingView
                }
            }

            Divider()

            // Footer with buttons
            footerView
        }
        .padding()
        .frame(width: 380)
        .frame(minHeight: 400, maxHeight: 550)
        .onAppear {
            generateQRCode()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                Text("Mobile Interface")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Scan to access Agent Deck from your phone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    // MARK: - Success View

    private func successView(qrImage: NSImage, url: String) -> some View {
        VStack(spacing: 16) {
            // QR Code image
            // Task: T058 - display QR code image
            Image(nsImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 4)

            // Instructions
            VStack(spacing: 12) {
                Text("How to connect:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(number: "1", text: "Open Camera on your phone")
                    instructionRow(number: "2", text: "Point at the QR code above")
                    instructionRow(number: "3", text: "Tap the notification to open")
                }
                .padding(.horizontal)
            }

            // URL text box
            // Task: T060 - display URL text for manual entry
            urlTextBox(url: url)
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .leading)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func urlTextBox(url: String) -> some View {
        VStack(spacing: 8) {
            Text("Or enter manually:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                // URL text (read-only)
                Text(url)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                // Copy button
                // Task: T060 - copyable URL text
                Button(action: {
                    copyToClipboard(url)
                }) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .foregroundColor(showCopiedFeedback ? .green : .accentColor)
                }
                .buttonStyle(.plain)
                .help("Copy URL to clipboard")
            }

            if showCopiedFeedback {
                Text("Copied!")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Connection Required")
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Error-specific help text
            if message.contains("WiFi") {
                Text("Make sure your Mac is connected to a WiFi network.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Generating QR code...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Network info
            if let url = localURL {
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.caption)
                    Text(extractIPAddress(from: url))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Refresh button
            Button(action: {
                generateQRCode()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .help("Refresh QR code if your IP address changed")

            // Done button
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    /// Generate QR code from current network configuration
    /// Tasks: T058-T060 - generate and display QR with URL
    private func generateQRCode() {
        // Reset state
        errorMessage = nil
        qrImage = nil
        localURL = nil
        showCopiedFeedback = false

        // Generate QR code
        if let result = QRGenerator.generateMobileAccessQR(port: port) {
            qrImage = result.image
            localURL = result.url
            Logger.info("QR code generated successfully", log: Logger.general)
        } else {
            // Check specific error
            // Task: T061 - error handling for missing WiFi
            if QRGenerator.getLocalIPAddress() == nil {
                errorMessage = NetworkError.noWiFiConnection.errorDescription
                Logger.warning("Cannot generate QR: no WiFi connection", log: Logger.network)
            } else {
                errorMessage = NetworkError.qrGenerationFailed.errorDescription
                Logger.error("Cannot generate QR: unknown error", log: Logger.general)
            }
        }
    }

    /// Copy URL to clipboard
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Show feedback
        withAnimation {
            showCopiedFeedback = true
        }

        // Hide feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }

        Logger.info("URL copied to clipboard: \(text)", log: Logger.general)
    }

    /// Extract IP address from URL for display
    private func extractIPAddress(from url: String) -> String {
        if let range = url.range(of: "://"),
           let endRange = url.range(of: ":", range: range.upperBound..<url.endIndex) {
            return String(url[range.upperBound..<endRange.lowerBound])
        }
        return url
    }
}

// MARK: - Preview

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView()
    }
}
