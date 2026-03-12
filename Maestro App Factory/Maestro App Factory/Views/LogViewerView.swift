//
//  LogViewerView.swift
//  Maestro App Factory
//

import Combine
import SwiftUI

struct LogViewerView: View {
    let logPath: String
    @State private var logContent: String = "Loading..."
    @State private var autoScroll = true
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(logPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logContent, forType: .string)
                }
                .font(.caption)

                Button("Refresh") {
                    loadLog()
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Log content — AppKit NSTextView for reliable rendering
            LogTextView(text: $logContent, autoScroll: autoScroll)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear { loadLog() }
        .onReceive(timer) { _ in loadLog() }
    }

    private func loadLog() {
        do {
            let content = try String(contentsOfFile: logPath, encoding: .utf8)
            logContent = content.isEmpty ? "(Log file is empty)" : content
        } catch {
            logContent = "Could not read log file:\n\(logPath)\n\nError: \(error.localizedDescription)"
        }
    }
}

/// AppKit-backed scrollable text view for reliable rendering
struct LogTextView: NSViewRepresentable {
    @Binding var text: String
    let autoScroll: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        textView.string = text

        if autoScroll {
            textView.scrollToEndOfDocument(nil)
        }
    }
}
