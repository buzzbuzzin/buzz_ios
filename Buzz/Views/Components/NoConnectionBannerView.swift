//
//  NoConnectionBannerView.swift
//  Buzz
//
//  Created by Xinyu Fang on 3/20/26.
//

import SwiftUI

struct NoConnectionBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            Text("No Internet Connection")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
