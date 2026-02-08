//
//  EventsView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

struct EventsView: View {
    @State private var selectedTab: EventTab = .webinars

    enum EventTab: String, CaseIterable {
        case webinars = "Webinars"
        case expos = "Expos"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.8), .pink.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("Events")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Webinars, expos, and drone community events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Tab Picker
                Picker("Event Type", selection: $selectedTab) {
                    ForEach(EventTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Content
                switch selectedTab {
                case .webinars:
                    webinarsSection
                case .expos:
                    exposSection
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Webinars Section

    private var webinarsSection: some View {
        VStack(spacing: 16) {
            // Coming Soon Card
            VStack(spacing: 16) {
                Image(systemName: "video.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple.opacity(0.7))

                Text("Webinars Coming Soon")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Live and recorded webinars hosted by Buzz and industry experts covering drone operations, regulations, best practices, and more.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Sample upcoming topics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming Topics")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    EventTopicRow(icon: "book.closed.fill", color: .blue, title: "Aviation Regulation Workshop")
                    EventTopicRow(icon: "camera.fill", color: .orange, title: "Aerial Photography Masterclass")
                    EventTopicRow(icon: "shield.checkered", color: .green, title: "Safety & Risk Management")
                    EventTopicRow(icon: "building.2.fill", color: .indigo, title: "Commercial Drone Operations")
                }
                .padding(16)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Expos Section

    private var exposSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 40))
                    .foregroundColor(.pink.opacity(0.7))

                Text("Drone Expos & Events")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Discover upcoming drone expos, trade shows, meetups, and community events happening near you and around the world.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Sample event types
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Types")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    EventTopicRow(icon: "building.columns.fill", color: .purple, title: "Trade Shows & Expos")
                    EventTopicRow(icon: "person.3.fill", color: .mint, title: "Community Meetups")
                    EventTopicRow(icon: "flag.checkered", color: .red, title: "Racing Events")
                    EventTopicRow(icon: "graduationcap.fill", color: .cyan, title: "Training Workshops")
                }
                .padding(16)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Event Topic Row

struct EventTopicRow: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text("Coming Soon")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
        }
    }
}
