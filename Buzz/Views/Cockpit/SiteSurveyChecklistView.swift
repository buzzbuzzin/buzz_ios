//
//  SiteSurveyChecklistView.swift
//  Buzz
//
//  Created for site survey within checklist tab
//

import SwiftUI
import Auth

struct SiteSurveyChecklistView: View {
    @EnvironmentObject var authService: AuthService
    let booking: Booking

    var body: some View {
        SiteSurveyFormView(booking: booking, isEmbedded: true)
            .environmentObject(authService)
    }
}
