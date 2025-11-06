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
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
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
        .navigationTitle("Help")
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

