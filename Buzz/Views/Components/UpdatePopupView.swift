//
//  UpdatePopupView.swift
//  Buzz
//
//  Created by AI Assistant on 01/20/26.
//

import SwiftUI

struct UpdatePopupView: View {
    @ObservedObject var updateService: AppUpdateService
    @Binding var isPresented: Bool
    private let changelogURL = URL(string: "https://www.buzzbuzzin.com/changelog")
    
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var updateTitle: String {
        if let latestVersion = updateService.latestVersion {
            return "Buzz \(latestVersion) is ready"
        }
        return "Buzz update available"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .overlay {
                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.16),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 10,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                VStack(spacing: 22) {
                    heroSection
                    highlightsSection
                    footerSection

                    VStack(spacing: 10) {
                        Button {
                            updateService.openAppStore()
                            isPresented = false
                        } label: {
                            Label("Open App Store", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(UpdatePopupPrimaryButtonStyle())

                        Button {
                            updateService.dismissUpdate()
                            isPresented = false
                        } label: {
                            Text("Maybe Later")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        }
                        .buttonStyle(UpdatePopupSecondaryButtonStyle())
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: 360)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(.systemBackground))

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 18)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Update available popup")
            .accessibilityHint("Install the latest Buzz version or dismiss this prompt for now.")
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            Text("APP STORE UPDATE")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.96),
                                Color.cyan.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    .padding(4)

                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 76, height: 76)
            .shadow(color: .blue.opacity(0.25), radius: 18, x: 0, y: 10)

            VStack(spacing: 8) {
                Text(updateTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Install the latest version from the App Store to stay current and keep the experience running smoothly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let latestVersion = updateService.latestVersion {
                HStack(spacing: 12) {
                    versionPill(title: "Latest", value: latestVersion, backgroundColor: Color.blue.opacity(0.12))
                    versionPill(title: "Installed", value: currentVersion, backgroundColor: Color(.systemGray6))
                }
            }
        }
    }
    
    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(updateHighlights) { highlight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: highlight.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 30, height: 30)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(highlight.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(highlight.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private var footerSection: some View {
        if let changelogURL {
            HStack(spacing: 6) {
                Text("Want the details?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link("Read the changelog", destination: changelogURL)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .multilineTextAlignment(.center)
        }
    }
    
    private func versionPill(title: String, value: String, backgroundColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var updateHighlights: [UpdateHighlight] {
        [
            UpdateHighlight(
                icon: "sparkles",
                title: "Newest features",
                message: "Stay current with the latest improvements and product updates."
            ),
            UpdateHighlight(
                icon: "bolt.fill",
                title: "Better performance",
                message: "Pick up responsiveness and stability improvements from the latest build."
            ),
            UpdateHighlight(
                icon: "checkmark.seal.fill",
                title: "Ongoing reliability fixes",
                message: "Move to the current release so you are not stuck on older issues."
            )
        ]
    }
}

private struct UpdatePopupPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color.blue,
                        Color.blue.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .blue.opacity(0.26), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct UpdatePopupSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(Color(.systemBackground).opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct UpdateHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
}

#Preview {
    let updateService = AppUpdateService()
    updateService.isUpdateAvailable = true
    updateService.latestVersion = "2.1.0"

    return ZStack {
        Color.gray.opacity(0.3)
            .edgesIgnoringSafeArea(.all)

        UpdatePopupView(updateService: updateService, isPresented: .constant(true))
    }
}
