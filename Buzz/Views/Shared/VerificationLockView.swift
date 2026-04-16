//
//  VerificationLockView.swift
//  Buzz
//
//  Created by Xinyu Fang on 4/16/26.
//

import SwiftUI

struct VerificationLockView: View {
    let tabTitle: String
    let onVerifyTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            Text("\(tabTitle) Locked")
                .font(.title2)
                .fontWeight(.bold)

            Text("Verify your identity with a government ID to unlock Buzz.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            CustomButton(title: "Verify Identity", action: onVerifyTapped)
                .frame(maxWidth: 280)
                .padding(.horizontal)
                .padding(.top, 4)

            Text("You can still manage your Account from the tab bar.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tabTitle) locked. Verify your identity with a government ID to unlock Buzz.")
    }
}
