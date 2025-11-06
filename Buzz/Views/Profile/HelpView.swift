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
            
            // Get help with a safety issue
            NavigationLink(destination: SafetyIssueView()) {
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
        }
        .navigationTitle("Get help")
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
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Help Center")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Our help center is coming soon. In the meantime, please use the feedback option to contact us with any questions.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safety Issue View

struct SafetyIssueView: View {
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
                Text("Safety Issue")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("If you've experienced or witnessed a safety issue, please report it immediately. We take safety very seriously and will respond promptly.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Subject Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Brief description of the safety issue", text: $subject)
                        .textContentType(.none)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Message Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Please provide as much detail as possible about the safety issue...")
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
                    title: "Report Safety Issue",
                    action: sendMessage,
                    isDisabled: subject.isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Safety Issue")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                subject: "Safety Issue: \(subject)",
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
