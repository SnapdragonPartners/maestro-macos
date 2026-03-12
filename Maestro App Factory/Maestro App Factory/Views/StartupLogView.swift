//
//  StartupLogView.swift
//  Maestro App Factory
//

import SwiftUI

struct StartupLogView: View {
    var appState: AppState
    let onQuit: () -> Void

    private var showRestart: Bool {
        if case .error = appState.status { return true }
        if case .stopped = appState.status { return true }
        return false
    }

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

            if showRestart {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await appState.restartMaestro()
                        }
                    } label: {
                        Text("Restart")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        appState.showDirectoryPicker()
                        if appState.projectDirectory != nil {
                            Task {
                                await appState.restartMaestro()
                            }
                        }
                    } label: {
                        Text("Change Project...")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if appState.projectDirectory != nil {
                    Button {
                        appState.showLogViewer()
                    } label: {
                        Text("View Maestro Log...")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

            HStack(spacing: 12) {
                Button(action: onQuit) {
                    Text("Quit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer().frame(height: 4)
        }
        .padding(.horizontal, 20)
        .frame(width: 420)
    }

}
