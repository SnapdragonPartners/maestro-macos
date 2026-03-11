//
//  DockerWaitingView.swift
//  Maestro App Factory
//

import SwiftUI

struct DockerWaitingView: View {
    let isInstalled: Bool
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            Image(systemName: isInstalled ? "arrow.clockwise.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(isInstalled ? .blue : .orange)

            Text(isInstalled ? "Waiting for Docker" : "Docker Required")
                .font(.title2.bold())

            Text(isInstalled
                 ? "Start Docker Desktop to continue. Maestro will start automatically once Docker is ready."
                 : "Maestro requires Docker Desktop to run. Please install and start Docker Desktop.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 300)

            if !isInstalled {
                Button(action: downloadDocker) {
                    Text("Download Docker Desktop")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for Docker...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text("[Don't have Docker? Get it free here.](https://www.docker.com/products/docker-desktop/)")
                .font(.caption)

            Divider()

            Button(action: onQuit) {
                Text("Quit Maestro")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer().frame(height: 4)
        }
        .padding(.horizontal, 30)
        .frame(width: 380)
    }

    private func downloadDocker() {
        NSWorkspace.shared.open(URL(string: "https://www.docker.com/products/docker-desktop/")!)
    }
}
