//
//  HelpView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import MessageUI
import Auth

struct HelpView: View {
    var body: some View {
        List {
            // Visit the Help Center
            NavigationLink(destination: HelpCenterView()) {
                HelpCard(
                    icon: "book.fill",
                    title: "Visit the Help Center",
                    description: "Browse articles and find answers to common questions"
                )
            }
            
            // Chat with us
            NavigationLink(destination: ChatSupportView()) {
                HelpCard(
                    icon: "message.fill",
                    title: "Chat with us",
                    description: "Didn't find what you need? Chat with our customer service representatives to solve your problem"
                )
            }
            
            // Get help with a safety issue
            NavigationLink(destination: TicketReportListView(reportType: .safety)) {
                HelpCard(
                    icon: "shield.fill",
                    title: "Get help with a safety issue",
                    description: "Report safety concerns or incidents"
                )
            }
            
            // Give us feedback
            NavigationLink(destination: FeedbackView()) {
                HelpCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Give us feedback",
                    description: "Share your thoughts and suggestions with us"
                )
            }

            // Report a bug
            NavigationLink(destination: TicketReportListView()) {
                HelpCard(
                    icon: "ladybug.fill",
                    title: "Report a bug",
                    description: "Submit and track bug reports for issues you encounter"
                )
            }
        }
        .navigationTitle("Get Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Card

struct HelpCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var searchText = ""
    
    private let articles = HelpCenterArticle.library
    
    private var filteredArticles: [HelpCenterArticle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return articles }
        return articles.filter { $0.matches(query) }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 58, height: 58)
                            
                            Image(systemName: "book.pages.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pilot Help Center")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Detailed instructions for booking workflows, pilot credentials, Buzz Academy, exams, payouts, and support.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            HelpCenterStatChip(icon: "doc.text.fill", text: "\(articles.count) guides")
                            HelpCenterStatChip(icon: "airplane.departure", text: "Pilot-focused")
                            HelpCenterStatChip(icon: "graduationcap.fill", text: "Academy + exams")
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            
            if filteredArticles.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("No matching articles")
                            .font(.headline)
                        
                        Text("Try searching for booking, Academy, reviewer, ROC-A, payout, or license.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(HelpCenterCategory.allCases) { category in
                    let categoryArticles = filteredArticles.filter { $0.category == category }
                    
                    if !categoryArticles.isEmpty {
                        Section {
                            ForEach(categoryArticles) { article in
                                NavigationLink(destination: HelpCenterArticleDetailView(article: article)) {
                                    HelpCenterArticleRow(article: article)
                                }
                            }
                        } header: {
                            HelpCenterCategoryHeader(category: category)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search pilot help")
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum HelpCenterCategory: String, CaseIterable, Identifiable {
    case gettingStarted
    case bookings
    case credentials
    case academy
    case support
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .gettingStarted:
            return "Getting Started"
        case .bookings:
            return "Bookings"
        case .credentials:
            return "Credentials"
        case .academy:
            return "Buzz Academy"
        case .support:
            return "Support"
        }
    }
    
    var subtitle: String {
        switch self {
        case .gettingStarted:
            return "Set up the account a pilot needs before flying"
        case .bookings:
            return "Accept work, run jobs, finish flights, and get paid"
        case .credentials:
            return "Manage licenses and approval-based pilot permits"
        case .academy:
            return "Enroll in classes, unlock content, and use Test Center"
        case .support:
            return "Know when to escalate, report, or contact Buzz"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted:
            return "checklist"
        case .bookings:
            return "airplane.departure"
        case .credentials:
            return "checkmark.seal.fill"
        case .academy:
            return "graduationcap.fill"
        case .support:
            return "lifepreserver.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .gettingStarted:
            return .blue
        case .bookings:
            return .orange
        case .credentials:
            return .teal
        case .academy:
            return .indigo
        case .support:
            return .pink
        }
    }
}

private struct HelpCenterArticle: Identifiable {
    let id: String
    let title: String
    let summary: String
    let icon: String
    let accent: Color
    let category: HelpCenterCategory
    let readTime: String
    let keywords: [String]
    let sections: [HelpCenterArticleSection]
    
    func matches(_ query: String) -> Bool {
        let normalized = query.lowercased()
        let searchableText = (
            [title, summary] +
            keywords +
            sections.map(\.title) +
            sections.flatMap(\.paragraphs) +
            sections.flatMap(\.steps) +
            sections.flatMap(\.tips)
        ).joined(separator: " ").lowercased()
        
        return searchableText.contains(normalized)
    }
}

private struct HelpCenterArticleSection: Identifiable {
    let id = UUID()
    let title: String
    let paragraphs: [String]
    let steps: [String]
    let tips: [String]
}

private struct HelpCenterStatChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .fixedSize()
    }
}

private struct HelpCenterCategoryHeader: View {
    let category: HelpCenterCategory
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .foregroundColor(category.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .textCase(nil)
    }
}

private struct HelpCenterArticleRow: View {
    let article: HelpCenterArticle
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(article.accent.opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Image(systemName: article.icon)
                    .font(.title3)
                    .foregroundColor(article.accent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 12)
                    
                    Text(article.readTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    Image(systemName: article.category.icon)
                        .font(.caption2)
                    Text(article.category.title)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(article.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(article.accent.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HelpCenterArticleDetailView: View {
    let article: HelpCenterArticle
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [article.accent.opacity(0.85), article.accent.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: article.icon)
                                .font(.title2)
                            Text(article.category.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                            Text(article.readTime)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        
                        Text(article.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(article.summary)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
                .padding(.top, 8)
                
                ForEach(article.sections) { section in
                    HelpCenterArticleSectionCard(section: section, accent: article.accent)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Still Need Help?")
                        .font(.headline)
                    Text("Use Chat with us for account-specific questions, Get help with a safety issue for urgent operational concerns, Give us feedback for product suggestions, and Report a bug when something in the app is broken.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct HelpCenterArticleSectionCard: View {
    let section: HelpCenterArticleSection
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(section.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !section.steps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(accent)
                                .clipShape(Circle())
                            
                            Text(step)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            if !section.tips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                                .font(.subheadline)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .background(accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private extension HelpCenterArticle {
    static let library: [HelpCenterArticle] = [
        HelpCenterArticle(
            id: "pilot-setup-checklist",
            title: "Pilot Setup Checklist",
            summary: "Finish the account, identity, credential, and payout steps that make the rest of the app work smoothly.",
            icon: "checklist",
            accent: .blue,
            category: .gettingStarted,
            readTime: "4 min",
            keywords: ["setup", "getting started", "government id", "pilot licenses", "payment account", "notifications", "drone registration", "insurance"],
            sections: [
                HelpCenterArticleSection(
                    title: "What to complete first",
                    paragraphs: [
                        "Before you start accepting work, make sure the core pilot account items are complete. Buzz surfaces these items across Profile, License, Account, and Academy flows, so leaving one unfinished usually blocks something else later.",
                        "The fastest path is to finish your identity check, upload your pilot credentials, connect your payout account, and then review notifications and region settings."
                    ],
                    steps: [
                        "Open the Account tab and review Profile, Settings, Government ID, Pilot Licenses, Payment Account, Drone Registration, and Insurance.",
                        "Update your visible pilot information first so customers and internal review flows see the correct call sign, name, and contact details.",
                        "Complete Government ID verification before trying to accept bookings or enroll in Academy content that requires identity verification.",
                        "Upload your pilot licenses early even if you are still learning the app, because OCR review and approval-based credentials take time.",
                        "Connect Payment Account before your first completed booking so payouts are not delayed when work starts closing out."
                    ],
                    tips: [
                        "Government ID verification is a hard requirement for pilots before accepting bookings.",
                        "Academy region selection affects which local courses are shown by default, so set Region in Settings before building a training plan.",
                        "If a screen looks empty, that often means the prerequisite item lives in another Profile section rather than the feature itself."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Identity, licenses, and operations readiness",
                    paragraphs: [
                        "Buzz separates identity verification from pilot document uploads. Government ID proves the account holder is real, while Pilot Licenses stores the aviation and radio credentials that support specific flight or examiner capabilities.",
                        "Operational add-ons like Drone Registration and Insurance sit in the same pilot profile area because they are part of being job-ready even when a specific booking does not force them upfront."
                    ],
                    steps: [
                        "In Government ID, authenticate with Face ID and complete the Stripe Identity flow with a government-issued ID and selfie.",
                        "In Pilot Licenses, upload each certificate as a PDF or image and choose the exact license type when prompted.",
                        "Review the OCR fields after upload and correct any extracted name, date, course, or certificate number that looks wrong.",
                        "Add drone registration and insurance information if you will be taking jobs that require stronger proof of operational readiness."
                    ],
                    tips: [
                        "OCR is a convenience feature, not the source of truth. Always check the extracted information before leaving the screen.",
                        "Approval-based credentials like Flight Reviewer and ROC-A Examiner create a separate review request and may show Under Review or Rejected states."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Payout and communications",
                    paragraphs: [
                        "A pilot account is not really ready until both money flow and communication flow are tested. Jobs, ratings, reminders, disputes, and Academy renewals all depend on you seeing alerts and having somewhere for payouts to land."
                    ],
                    steps: [
                        "Open Payment Account and complete the payout setup so completed bookings can settle correctly.",
                        "Open Settings and confirm Notifications plus your communication preference so booking and exam updates reach you.",
                        "If you plan to study in Academy, review Buzz Academy Pass from Account as well so you understand what is free and what requires a subscription."
                    ],
                    tips: [
                        "Use Get Help once now, not only when something breaks, so you know where Chat, Safety Issue, Feedback, and Bug Report live.",
                        "Keeping setup current prevents the most common pilot frustration: finding a job or course and then hitting a block several screens later."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "accept-booking",
            title: "How to Accept a Booking",
            summary: "Find available jobs, review the details, clear the identity requirement, and move the booking into your active flight list.",
            icon: "airplane.departure",
            accent: .orange,
            category: .bookings,
            readTime: "5 min",
            keywords: ["accept booking", "jobs", "my flights", "available bookings", "identity verification", "join mission", "join crew"],
            sections: [
                HelpCenterArticleSection(
                    title: "Where pilots find jobs",
                    paragraphs: [
                        "Pilots browse work from the Jobs tab. This list supports category filters and a search radius, so it is designed for scanning nearby opportunities quickly before opening a full booking detail page.",
                        "Once you accept a job, it stops being just a listing and becomes part of your active workload inside My Flights."
                    ],
                    steps: [
                        "Open the Jobs tab.",
                        "Use the specialization chips across the top if you only want certain mission types.",
                        "Expand Search Radius to tighten or widen the distance filter based on how far you are willing to travel.",
                        "Open a booking card to read the full booking detail, schedule, pay, address, specialization, and any crew requirements."
                    ],
                    tips: [
                        "Expired jobs are filtered out of the available list, so if a listing disappears it may have timed out or been accepted.",
                        "Crew bookings use Join Crew or Join Mission language instead of the standard Accept Booking button."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "What blocks acceptance",
                    paragraphs: [
                        "The app checks pilot identity before allowing acceptance. If you are not verified, the booking detail page disables the accept action and tells you that identity verification is required.",
                        "License readiness also matters operationally. Buzz encourages you to upload your pilot certificates early so the account is clearly flight-ready."
                    ],
                    steps: [
                        "If the booking detail shows Identity verification required to accept bookings, leave the booking and go to Account > Government ID.",
                        "Finish or retry the Stripe Identity flow until the status becomes verified.",
                        "Return to the booking detail page after verification and review the booking again before accepting."
                    ],
                    tips: [
                        "Government ID is the explicit in-app blocker for booking acceptance.",
                        "Keeping Pilot Licenses current is still recommended before taking work, especially if you expect your account to be reviewed."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "The actual acceptance flow",
                    paragraphs: [
                        "Regular jobs and crew jobs diverge at the final button, but the review discipline is the same: check timing, location, scope, pay, and whether the mission type fits your equipment and rank."
                    ],
                    steps: [
                        "In Booking Details, tap Accept Booking for a standard job, or Join Crew / Join Mission for a crew-based job.",
                        "Confirm the alert when Buzz asks whether you are sure you want to accept or join.",
                        "Wait for the booking to refresh. A successful acceptance updates the booking state and the listing leaves the available pool.",
                        "Open My Flights to confirm the booking appears under Active once you are assigned."
                    ],
                    tips: [
                        "Crew missions can remain in an available state while the crew is still filling, so do not assume available always means unassigned to everyone.",
                        "Notifications and deep links can bring you back into Booking Details later for reminders, cancellation updates, and accepted-booking events."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "run-booking",
            title: "Run a Booking from Acceptance to Completion",
            summary: "Use the booking detail page as the operational control center for start, finish, confirmation, hours, and payout-related milestones.",
            icon: "airplane.circle.fill",
            accent: .orange,
            category: .bookings,
            readTime: "6 min",
            keywords: ["start job", "finish booking", "confirm completion", "my flights", "completed booking", "flight hours", "balance"],
            sections: [
                HelpCenterArticleSection(
                    title: "After the job is accepted",
                    paragraphs: [
                        "Accepted and staffed bookings move into My Flights. That screen separates active work from completed work so you can reopen the booking detail whenever you need the address, customer, timing, or workflow buttons.",
                        "The booking detail page changes its primary action based on status, which is why pilots should keep returning there instead of expecting one static flow."
                    ],
                    steps: [
                        "Open My Flights and select the accepted booking under Active.",
                        "Review any customer details, directions, messages, and preparation items before departure.",
                        "For staffed or accepted jobs assigned to you, tap Start Job when the operation is actually beginning."
                    ],
                    tips: [
                        "Start Job moves the booking to In Progress and notifies the customer.",
                        "Crew and search-and-rescue workflows may keep additional status context around staffing before the start step appears."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "How finishing works",
                    paragraphs: [
                        "Buzz uses a confirmation model for completion. Sometimes you finish first and wait for the customer. Sometimes the customer marks it finished first and you confirm second. The booking detail page handles both cases."
                    ],
                    steps: [
                        "When the mission is done and the booking is In Progress, tap Finish Booking.",
                        "If Buzz tells you the finish is waiting on the customer, stop there and monitor the booking until the customer confirms.",
                        "If the customer marks the booking finished first, reopen the booking and tap Confirm Completion.",
                        "Once both sides are complete, the booking closes and Buzz shows the completion success state."
                    ],
                    tips: [
                        "For non-automotive bookings, pilot flight hours are updated when the booking fully completes.",
                        "Completed jobs move out of Active and into the Completed section of My Flights."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "What happens after completion",
                    paragraphs: [
                        "Completion is not just a status change. It is the point where hours, ratings, disputes, and balance updates start to matter, so pilots should check the post-flight actions before mentally closing the job."
                    ],
                    steps: [
                        "After completion, rate the customer if Buzz prompts you to leave a rating.",
                        "Open your balance or payout-related profile areas if you want to confirm the financial side after the booking closes.",
                        "If there is a problem with the job outcome, use the File Dispute action from the completed booking screen."
                    ],
                    tips: [
                        "If something operationally serious happened during the mission, also use the separate Safety Issue path under Get Help rather than relying on a dispute alone.",
                        "Keep messages and supporting details in the booking thread when possible so the timeline is easier to reconstruct later."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "messages-ratings-disputes",
            title: "Messaging, Ratings, and Disputes",
            summary: "Know when chat is available, when customer ratings appear, and how to escalate a completed job that went wrong.",
            icon: "message.badge.fill",
            accent: .pink,
            category: .bookings,
            readTime: "4 min",
            keywords: ["message customer", "chat", "rate customer", "file dispute", "completed booking", "review"],
            sections: [
                HelpCenterArticleSection(
                    title: "When messaging is available",
                    paragraphs: [
                        "Buzz intentionally limits some communication states. Messaging becomes useful once a booking is truly underway or established, which reduces noise around listings that never convert.",
                        "Accepted, staffed, in-progress, and completed workflows expose message-related actions in booking and conversation views."
                    ],
                    steps: [
                        "Open an accepted or completed booking from My Flights.",
                        "Use the message action from the booking detail page when available.",
                        "Continue the conversation inside the booking thread so both sides stay attached to the same context."
                    ],
                    tips: [
                        "Do not wait until arrival to message a customer if a timing or access issue is already obvious.",
                        "Keeping communication inside Buzz is stronger than moving immediately to external channels."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Ratings after a finished job",
                    paragraphs: [
                        "Once a booking reaches completed status, pilots can rate the customer. This is part of the closeout workflow and helps future pilots understand what working with that customer is like."
                    ],
                    steps: [
                        "Finish the booking and wait until the job is fully completed.",
                        "Tap Rate Customer when the booking detail page offers it.",
                        "Submit both the star rating and the comment so the review is useful rather than just numeric."
                    ],
                    tips: [
                        "Ratings are tied to the booking, so be accurate and professional.",
                        "If you already rated the customer, Buzz will stop showing that action on the same booking."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "When to file a dispute instead",
                    paragraphs: [
                        "A bad review is not the same as a dispute. Use File Dispute when there is an actual conflict about payment, conduct, scope, or completion rather than just a routine inconvenience."
                    ],
                    steps: [
                        "Open the completed booking.",
                        "Tap File Dispute.",
                        "Submit the dispute with enough detail for the support team to understand what happened and what resolution you believe is appropriate."
                    ],
                    tips: [
                        "If the issue is also a safety event, report it through Get help with a safety issue immediately.",
                        "Disputes are strongest when the booking chat, timing, and job actions already tell a consistent story."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "pilot-licenses",
            title: "Upload and Manage Pilot Licenses",
            summary: "Use the Pilot Licenses area to store credentials, review OCR results, edit extracted fields, and track approval states.",
            icon: "doc.badge.plus",
            accent: .teal,
            category: .credentials,
            readTime: "6 min",
            keywords: ["pilot licenses", "ocr", "license upload", "approval", "edit license", "reupload", "certificate number"],
            sections: [
                HelpCenterArticleSection(
                    title: "What the Pilot Licenses screen does",
                    paragraphs: [
                        "Pilot Licenses is not just a file cabinet. It stores document images or PDFs, runs OCR, groups credentials by category, and shows approval status for permit-style credentials that require manual review.",
                        "The categories include Drone Pilot License, Radio Operator Permit Type, Flight Reviewer, Examiner, and Other."
                    ],
                    steps: [
                        "Open Account > Pilot Licenses.",
                        "Authenticate with Face ID when prompted, because the app treats pilot documents as sensitive information.",
                        "Tap Upload License if your account has no documents yet, or add more credentials from the upload flow when you already have licenses on file.",
                        "Choose the exact license type before uploading so OCR and review logic can interpret the document correctly."
                    ],
                    tips: [
                        "License type selection matters. Buzz treats ROC-A Examiner and Flight Reviewer differently from normal pilot certificates.",
                        "If your document does not fit a built-in type, use the Other / Custom path so you can still store it."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "OCR review and edits",
                    paragraphs: [
                        "After upload, Buzz extracts fields such as name, course completed, completion or issue date, and certificate or examiner number. Those fields power a cleaner review process, but OCR can misread real-world documents."
                    ],
                    steps: [
                        "Open the license card after upload and read the Extracted Information area carefully.",
                        "Tap Edit if the name, date, course, FRN, certificate number, serial number, or examiner number is incorrect.",
                        "Save the corrected data so future review and profile workflows rely on the right values.",
                        "Use View when you need to compare the stored document against the extracted fields."
                    ],
                    tips: [
                        "Buzz explicitly warns that OCR may not parse documents correctly, so manual review is part of the expected workflow.",
                        "Correcting fields early is better than waiting for a rejection caused by obvious OCR mistakes."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Approval statuses and re-uploads",
                    paragraphs: [
                        "Most basic license storage is immediate, but reviewer and examiner credentials also create approval requests. Those requests can show Under Review, Approved, Rejected, or Document Deleted states.",
                        "Rejected cards can include reviewer notes and a one-tap re-upload path, which is much faster than guessing what failed."
                    ],
                    steps: [
                        "Watch the status badge on credentials that require approval.",
                        "If the status is Under Review, wait for the Buzz team to complete the check.",
                        "If the status is Rejected, read the reviewer notes first so you know whether the issue is the wrong document, incomplete document, or bad extracted information.",
                        "Use Re-upload License from the rejected card and submit the corrected file."
                    ],
                    tips: [
                        "The UI currently tells pilots that pending review typically takes one to two business days.",
                        "Do not delete and re-upload blindly if reviewer notes already explain the exact correction needed."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "flight-reviewer",
            title: "How to Become a Flight Reviewer",
            summary: "Use Buzz to submit and maintain your Flight Reviewer credential after you have earned the underlying qualification outside the app.",
            icon: "person.text.rectangle.fill",
            accent: .teal,
            category: .credentials,
            readTime: "5 min",
            keywords: ["flight reviewer", "reviewer", "canada", "approval request", "license review"],
            sections: [
                HelpCenterArticleSection(
                    title: "What Buzz does and does not do",
                    paragraphs: [
                        "Buzz does not train you into a Flight Reviewer directly from this screen. The app manages the document submission, OCR extraction, and approval review after you already hold the appropriate real-world credential.",
                        "In other words, become qualified through the applicable authority first, then use Buzz to register that qualification on your pilot account."
                    ],
                    steps: [
                        "Make sure you already hold the Flight Reviewer credential you intend to represent on Buzz.",
                        "Prepare a clean image or PDF that clearly shows your name, credential details, and relevant identifying information."
                    ],
                    tips: [
                        "If your document is blurry, cropped, or missing information, the review request is much more likely to be rejected.",
                        "This workflow is specifically built around the Flight Reviewer credential category in Pilot Licenses."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Submitting the credential in Buzz",
                    paragraphs: [
                        "Buzz treats Flight Reviewer as an approval-based permit. Uploading the file stores the document and also creates a separate review request in the background."
                    ],
                    steps: [
                        "Open Account > Pilot Licenses.",
                        "Start a new upload and choose Flight Reviewer when selecting the license type.",
                        "Upload the supporting document as a PDF or image.",
                        "Review the OCR results on the resulting license card and fix any obvious mistakes with Edit.",
                        "Wait for the approval status badge to move from Under Review to an approved state."
                    ],
                    tips: [
                        "The approval badge appears directly on the license card, so you do not need a separate dashboard to monitor it.",
                        "Under Review currently indicates a manual check that typically takes one to two business days."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "If the request is rejected",
                    paragraphs: [
                        "Rejected does not mean the process is over. Buzz surfaces reviewer notes so you can correct the exact problem instead of guessing."
                    ],
                    steps: [
                        "Open the rejected Flight Reviewer license card.",
                        "Read the reviewer notes carefully.",
                        "Tap Re-upload License and submit the corrected or higher-quality document.",
                        "Re-check the extracted data after the new upload so the same avoidable issue does not repeat."
                    ],
                    tips: [
                        "Many rejections can be resolved by correcting OCR fields before re-uploading.",
                        "If the issue is policy-related rather than document quality, use Chat with us and reference the reviewer notes."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "roc-a-examiner",
            title: "How to Become a ROC-A Examiner",
            summary: "Register your ROC-A Examiner credential in Buzz, including the examiner number and review workflow that the app expects.",
            icon: "antenna.radiowaves.left.and.right",
            accent: .indigo,
            category: .credentials,
            readTime: "5 min",
            keywords: ["roc-a examiner", "examiner", "roc-a", "examiner number", "canada", "approval"],
            sections: [
                HelpCenterArticleSection(
                    title: "What the app expects from this credential",
                    paragraphs: [
                        "ROC-A Examiner is a separate credential class from a regular ROC-A certificate. Buzz stores it under the Examiner category, parses an examiner number, and tracks an approval request after upload.",
                        "That means you should not upload an ordinary ROC-A certificate under the examiner type just to fill the field. The underlying document needs to match the role."
                    ],
                    steps: [
                        "Confirm that you hold the ROC-A Examiner credential or authorization you want Buzz to recognize.",
                        "Prepare a readable document that includes your name, examiner number, and expiration information when applicable."
                    ],
                    tips: [
                        "Buzz has dedicated OCR handling for ROC-A Examiner documents, including examiner-number extraction.",
                        "A normal ROC-A certificate belongs under the Radio Operator Permit category, not Examiner."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Upload flow in Buzz",
                    paragraphs: [
                        "The upload path is similar to Flight Reviewer, but the field expectations are different. The edit screen labels the main identifier as Examiner Number and treats the date as an expiration date."
                    ],
                    steps: [
                        "Open Account > Pilot Licenses.",
                        "Start a new upload and choose ROC-A Examiner from the Examiner section of the license-type picker.",
                        "Upload the document and wait for the license card to appear.",
                        "Open the extracted information and confirm the name, expiration date, and examiner number are correct.",
                        "Edit the OCR fields if anything is missing or misread before waiting on review."
                    ],
                    tips: [
                        "The placeholder example for examiner number in the edit flow uses a short numeric value, so if OCR leaves it empty, fill it manually.",
                        "If the card shows Under Review, the review request was created and is waiting on Buzz approval."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Tracking status and correcting issues",
                    paragraphs: [
                        "ROC-A Examiner is approval-based, so status matters as much as storage. The goal is not only to upload a file but to get it into an approved state."
                    ],
                    steps: [
                        "Check the approval badge on the license card after upload.",
                        "If the request is approved, keep the card on file and update it again before expiration if required.",
                        "If the request is rejected, read the reviewer notes and use Re-upload License with a corrected document.",
                        "If you need help understanding the rejection, use Chat with us and include the credential type plus the examiner number you submitted."
                    ],
                    tips: [
                        "Keeping expiration data accurate matters because examiner authority is time-sensitive.",
                        "Do not leave a rejected examiner credential sitting in the profile if you expect Buzz to rely on it later."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "enroll-buzz-academy",
            title: "How to Enroll in Buzz Academy Classes",
            summary: "Choose the right course, satisfy identity and prerequisite rules, enroll, and understand what is free versus subscription-only.",
            icon: "graduationcap.fill",
            accent: .indigo,
            category: .academy,
            readTime: "7 min",
            keywords: ["academy", "enroll", "course", "academy pass", "region", "identity verification", "continue learning"],
            sections: [
                HelpCenterArticleSection(
                    title: "What you see when Academy opens",
                    paragraphs: [
                        "Academy is not a flat list of lessons. It is a filtered course catalog with provider chips, category chips, lock states, enrollment states, and region-based filtering.",
                        "If you have never selected a region, Buzz sends you through region onboarding first so the catalog can prioritize relevant local material."
                    ],
                    steps: [
                        "Open the Academy tab.",
                        "If prompted, choose your region and continue into the course catalog.",
                        "Use provider filters to switch between Buzz-hosted and external providers.",
                        "When Buzz is selected as the provider, use category chips to narrow the list further."
                    ],
                    tips: [
                        "Locked courses still appear in the catalog so you can see what to work toward next.",
                        "A locked course shows the exact missing prerequisite tests, which is usually more useful than hiding the course entirely."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "How enrollment works",
                    paragraphs: [
                        "Enrollment happens inside a course detail screen, not from the catalog card itself. Buzz also checks identity verification before allowing you to enroll in courses.",
                        "Buzz-hosted courses use an in-app enrollment action. External provider courses use a Go to Course flow and warn you before leaving the app."
                    ],
                    steps: [
                        "Open a course card from Academy.",
                        "Read the course detail page, including provider, region, duration, rating, and any external course warning.",
                        "If it is a Buzz course, tap Enroll Now.",
                        "If it is an external course, tap Go to Course and confirm the warning before Buzz opens the third-party site.",
                        "After successful enrollment, the button changes to Continue Learning or View Course Materials depending on completion state."
                    ],
                    tips: [
                        "If you see Verification Required, finish Account > Government ID first and then return to Academy.",
                        "You can unenroll from a course later, but Buzz warns that you will lose access to materials and progress."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Free content versus Academy Pass",
                    paragraphs: [
                        "Buzz Academy has a mixed-access model. Some units are free, while the rest of the catalog or deeper course content may require Buzz Academy Pass.",
                        "The current subscription messaging makes clear that Units 1 through 3 are free and Unit 4 unlocks after the Ground School test. Advanced units and extension content rely on the pass."
                    ],
                    steps: [
                        "Use the Buzz Academy Pass screens from Account or course subscription prompts if you need full content access.",
                        "Review whether your subscription is active and whether it came from Apple or the Buzz website flow.",
                        "If you already subscribe elsewhere, use Restore Purchases or the management path that matches your subscription source."
                    ],
                    tips: [
                        "External third-party courses are not covered by Buzz Academy Pass even if they appear inside Academy.",
                        "Subscription status can come from either Apple or Stripe-backed web purchase flows, and the management UI reflects that."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "test-center-exams",
            title: "Use Test Center for Exams and Scheduling",
            summary: "Track eligibility, schedule appointments, understand uploads, and know how Ground School, Flight Review, and ROC-A differ.",
            icon: "checkmark.seal.fill",
            accent: .indigo,
            category: .academy,
            readTime: "7 min",
            keywords: ["test center", "ground school", "flight review", "roc-a", "schedule exam", "appointment", "upload results", "prerequisites"],
            sections: [
                HelpCenterArticleSection(
                    title: "How Test Center is organized",
                    paragraphs: [
                        "Test Center shows the pilot's exam path, not just a list of random assessments. It checks your eligibility, shows appointments, separates available exams from passed exams, and reads test results per enrolled course.",
                        "Because tests come from enrolled courses, enrolling in the right Academy course is part of seeing the right exam opportunities."
                    ],
                    steps: [
                        "Open Academy and tap Test Center in the top-right corner.",
                        "Read the eligibility card near the top before trying to schedule anything.",
                        "Check My Appointments first if you think you already booked an exam.",
                        "Review Available Exams for the tests you have not yet passed."
                    ],
                    tips: [
                        "If a test does not appear, confirm that you are enrolled in the corresponding course.",
                        "Passed Exams can be collapsed, so expand that section if you are looking for history rather than upcoming actions."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Ground School, Flight Review, and ROC-A",
                    paragraphs: [
                        "The app treats these exams differently. Ground School is the foundational knowledge test. Flight Review and ROC-A depend on prerequisites and can involve scheduling, proctoring, or upload review depending on the test type configured by Buzz.",
                        "The fallback exam configuration in the app shows Flight Review and ROC-A requiring a passed Ground School test plus completion of Unit 4 in the UAS Pilot Course."
                    ],
                    steps: [
                        "Complete the required Academy units before expecting Ground School or advanced tests to unlock.",
                        "Use exam intro screens to review duration, format, price, prerequisites, and what to expect before scheduling.",
                        "For Flight Review, prepare for an in-person operational assessment.",
                        "For ROC-A, review whether the offered format is online or in-person for the current configuration."
                    ],
                    tips: [
                        "Buzz surfaces missing prerequisites directly, so treat those messages as your action list.",
                        "Course and test locking is deliberate and usually means you need to finish training content first, not that the app is broken."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Scheduling and result handling",
                    paragraphs: [
                        "Some tests are straightforward multiple-choice exams, while others require appointments or reviewed uploads. The UI uses scheduling, proctor, and upload cues to help you understand which kind you are dealing with."
                    ],
                    steps: [
                        "Open the exam card or exam intro screen and tap the schedule action when an appointment is required.",
                        "Choose the available slot and complete any payment flow tied to that exam.",
                        "Watch My Appointments for the scheduled exam details after booking.",
                        "For non-multiple-choice exams, upload the result materials if Buzz requests them after completion.",
                        "Wait for reviewed uploads to move from pending into an approved, passed state."
                    ],
                    tips: [
                        "A passed status on proctored or upload-reviewed exams may depend on approval, not only on the raw score.",
                        "Buzz can show pending review states, so do not assume silence means failure."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "academy-pass-recurrent",
            title: "Manage Buzz Academy Pass and Recurrent Training",
            summary: "Understand subscription status, where to manage it, and how recurrent notices and badge renewal fit into the Academy workflow.",
            icon: "repeat.circle.fill",
            accent: .indigo,
            category: .academy,
            readTime: "5 min",
            keywords: ["academy pass", "subscription", "restore purchases", "recurrent training", "renew badge", "manage subscription"],
            sections: [
                HelpCenterArticleSection(
                    title: "Checking your Academy Pass status",
                    paragraphs: [
                        "Buzz Academy Pass can come from an Apple in-app purchase or from the Buzz website subscription flow. The app checks both sources and presents one active status view.",
                        "That means you should manage the subscription based on where it originated rather than assuming every account behaves like a standard App Store purchase."
                    ],
                    steps: [
                        "Open Account > Buzz Academy Pass.",
                        "Read whether the pass is active and which source it came from.",
                        "If the pass is inactive, tap Subscribe Now or use a course subscription prompt from Academy."
                    ],
                    tips: [
                        "Apple subscriptions are managed in the App Store.",
                        "Website subscriptions are managed on the Buzz Academy website."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Restore and manage subscription access",
                    paragraphs: [
                        "Pilots often think access is missing when the real issue is that the current device has not refreshed entitlements yet. Buzz includes explicit restore and management actions for that reason."
                    ],
                    steps: [
                        "Use Restore Purchases if you bought through Apple and the pass is not showing correctly on the device.",
                        "Use Manage in App Store for Apple subscriptions or Manage on Website for Stripe-backed subscriptions.",
                        "Return to Academy after the subscription refresh completes and confirm the locked content has opened."
                    ],
                    tips: [
                        "Subscription checks run in both the pass management screen and Academy entry flows, so reopening Academy after changes is worthwhile.",
                        "External third-party courses remain outside Academy Pass coverage even when your pass is active."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "Recurrent training and badge renewal",
                    paragraphs: [
                        "Buzz tracks recurrent deadlines for enrolled courses that require periodic renewal. When due dates approach, recurrent notices appear near the top of Academy.",
                        "Completed recurrent courses can also drive badge renewal language inside the course detail screen."
                    ],
                    steps: [
                        "Watch the Recurrent Training Due area in Academy for courses nearing deadline.",
                        "Open the affected course and read the recurrent warning or badge expiration message.",
                        "Use Continue Learning or Renew Badge to complete the recurrent content before the due date."
                    ],
                    tips: [
                        "Courses with badges can show more urgent warning text when expiration is near or already passed.",
                        "Do not ignore recurrent notices if the badge or credential matters to your pilot profile or marketplace reputation."
                    ]
                )
            ]
        ),
        HelpCenterArticle(
            id: "support-escalation",
            title: "When to Use Chat, Safety Issue, Feedback, or Bug Report",
            summary: "Pick the right help channel so operational issues, feature requests, and software defects reach the correct team quickly.",
            icon: "lifepreserver.fill",
            accent: .pink,
            category: .support,
            readTime: "3 min",
            keywords: ["chat support", "safety issue", "feedback", "bug report", "get help"],
            sections: [
                HelpCenterArticleSection(
                    title: "Choose the correct support lane",
                    paragraphs: [
                        "Get Help already separates support by purpose. Using the right lane keeps operational issues from getting buried under feature suggestions and keeps product bugs from being mixed into ordinary account questions."
                    ],
                    steps: [
                        "Use Chat with us when you have an account-specific question or need a human to help you resolve a workflow problem.",
                        "Use Get help with a safety issue when something safety-related happened in the field or could create immediate operational risk.",
                        "Use Give us feedback when the app works but you want product changes, missing features, or better workflow design.",
                        "Use Report a bug when something in the app is broken, inconsistent, or failing to load or save correctly."
                    ],
                    tips: [
                        "A dispute is not the same as a software bug, and a bug is not the same as a safety issue.",
                        "Submitting through the correct path usually gets you a faster and more useful response."
                    ]
                ),
                HelpCenterArticleSection(
                    title: "What to include in a strong report",
                    paragraphs: [
                        "The best support requests are specific. The app already gives you dedicated forms for some cases, so use them to be concrete rather than writing a vague one-line complaint."
                    ],
                    steps: [
                        "Name the screen, feature, booking, course, or credential involved.",
                        "State what you expected to happen and what actually happened.",
                        "Include timing details, relevant statuses, and whether you already retried the action.",
                        "For safety reports, provide enough operational detail for Buzz to understand the risk immediately."
                    ],
                    tips: [
                        "If a help request is tied to a reviewer or examiner rejection, include the rejection notes you saw in Pilot Licenses.",
                        "If a problem only happens in one state of a booking or exam, mention that exact status."
                    ]
                )
            ]
        )
    ]
}


// MARK: - Feedback View

struct FeedbackView: View {
    @EnvironmentObject var authService: AuthService
    @State private var subject = ""
    @State private var message = ""
    @State private var showMailComposer = false
    @State private var showMailUnavailableAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Help & Support")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("Have a question or need assistance? Send us a message and we'll get back to you as soon as possible. Please note this is not for sensitive information.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Subject Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("What can we help you with?", text: $subject)
                        .textContentType(.none)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Message Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Tell us more about your question or concern...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Send Button
            VStack {
                CustomButton(
                    title: "Send Message",
                    action: sendMessage,
                    isDisabled: subject.isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Give us feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                subject: subject,
                messageBody: formattedMessageBody,
                toRecipients: ["hello@buzzbuzzin.com"],
                isPresented: $showMailComposer
            )
        }
        .alert("Email Unavailable", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Mail services are not available on this device. Please send an email to hello@buzzbuzzin.com from your email app.")
        }
    }
    
    private var formattedMessageBody: String {
        var body = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add user information if available
        if let userProfile = authService.userProfile {
            body += "\n\n---\n"
            body += "User Information:\n"
            body += "Name: \(userProfile.fullName)\n"
            if let email = userProfile.email {
                body += "Email: \(email)\n"
            }
            if let callSign = userProfile.callSign {
                body += "Call Sign: @\(callSign)\n"
            }
            body += "User Type: \(userProfile.userType == .pilot ? "Pilot" : "Customer")"
        }
        
        return body
    }
    
    private func sendMessage() {
        guard !subject.isEmpty,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailUnavailableAlert = true
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let messageBody: String
    let toRecipients: [String]
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(toRecipients)
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }
}

// MARK: - Chat Support View

struct ChatSupportView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Messages
            ScrollView {
                VStack(spacing: 16) {
                    if messages.isEmpty {
                        // Welcome message
                        VStack(spacing: 16) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Chat with us")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Hi! How can we help you today?")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .padding(12)
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Input Area
            HStack(spacing: 12) {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("Chat Support")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(text: inputText, isUser: true)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        
        // TODO: Integrate with AI chatbot API
        // Placeholder response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let botResponse = ChatMessage(
                text: "Thank you for your message. AI chatbot integration is coming soon! For immediate assistance, please use the 'Give us feedback' option or email us at hello@buzzbuzzin.com",
                isUser: false
            )
            messages.append(botResponse)
            isLoading = false
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}
