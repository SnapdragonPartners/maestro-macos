//
//  StartupLogView.swift
//  Maestro App Factory
//

import SwiftUI

struct StartupLogView: View {
    var appState: AppState
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 4)

            Text("Maestro")
                .font(.title2.bold())

            // Log area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(appState.startupLog.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .frame(height: 200)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                .onChange(of: appState.startupLog.count) {
                    if let last = appState.startupLog.indices.last {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            // Status bar
            HStack(spacing: 8) {
                switch appState.status {
                case .starting:
                    ProgressView().controlSize(.small)
                    Text("Starting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .error(let msg):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                case .stopped:
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text("Stopped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    EmptyView()
                }
                Spacer()
            }

            Divider()

            Button(action: onQuit) {
                Text("Quit Maestro")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer().frame(height: 4)
        }
        .padding(.horizontal, 20)
        .frame(width: 420)
    }
}
