//
//  WelcomeView.swift
//  Maestro App Factory
//

import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("MaestroLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120)

                Text("Welcome to Maestro App Factory\u{2122}")
                    .font(.title.bold())

                Text("A few things to know before you get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 24)

            // Info sections
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    infoSection(
                        icon: "menubar.arrow.up.rectangle",
                        title: "Menu Bar App",
                        text: "Maestro lives in your menu bar at the top of your screen \u{2014} look for the Maestro icon near your clock. There is no Dock icon. Click the menu bar icon to open the web UI, change projects, or quit. Don\u{2019}t see the menu bar icon? Check the FAQ."
                    )

                    infoSection(
                        icon: "shippingbox.fill",
                        title: "Docker Required",
                        text: "Docker is an app that keeps your system safe by running AI agents in isolation from the rest of your system. You\u{2019}ll need Docker Desktop installed and running before Maestro can start."
                    )

                    Link(destination: URL(string: "https://www.docker.com/products/docker-desktop/")!) {
                        Label("Download Docker Desktop", systemImage: "arrow.up.right.square")
                            .font(.callout)
                    }
                    .padding(.leading, 40)
                    .padding(.top, -12)

                    infoSection(
                        icon: "key.fill",
                        title: "Keys You\u{2019}ll Need",
                        text: "Maestro uses API keys to access services from AI providers and the code management platform GitHub. By default, you\u{2019}ll need keys for OpenAI, Anthropic, and GitHub. Not sure how to get these? Don\u{2019}t worry \u{2014} Maestro will walk you through it."
                    )

                    infoSection(
                        icon: "dollarsign.circle.fill",
                        title: "API Usage Costs",
                        text: "Maestro App Factory and the Maestro Control Panel are free, but API providers charge for usage. You are responsible for these costs."
                    )

                    infoSection(
                        icon: "doc.text.fill",
                        title: "License",
                        text: "Maestro App Factory is distributed under the MIT License."
                    )

                    Link(destination: URL(string: "https://opensource.org/licenses/MIT")!) {
                        Label("View MIT License", systemImage: "arrow.up.right.square")
                            .font(.callout)
                    }
                    .padding(.leading, 40)
                    .padding(.top, -12)

                }
                .padding(24)
            }

            Divider()
                .padding(.horizontal, 24)

            // Footer
            VStack(spacing: 8) {
                Text("By continuing, you acknowledge the above and agree to the terms of the MIT License.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Link(destination: URL(string: "https://maestroappfactory.ai")!) {
                    Label("FAQs and Support", systemImage: "arrow.up.right.square")
                        .font(.callout)
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 680)
    }

    private func infoSection(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
