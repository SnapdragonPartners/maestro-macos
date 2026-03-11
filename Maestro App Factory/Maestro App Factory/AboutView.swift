//
//  AboutView.swift
//  Maestro App Factory
//

import SwiftUI

struct AboutView: View {
    let maestroVersion: String?
    let controlPanelBuild: String?

    var body: some View {
        VStack(spacing: 16) {
            Image("MaestroLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150)

            if let version = maestroVersion {
                Text(version)
                    .font(.headline)
            }

            if let build = controlPanelBuild {
                Text("Control Panel build \(build)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.horizontal, 20)

            Text("Maestro App Factory\u{2122} and the Maestro Control Panel are products of Snapdragon Partners, LLC. and distributed under the MIT license.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("For support and more information visit [maestroappfactory.ai](https://maestroappfactory.ai)")
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 380)
    }
}
