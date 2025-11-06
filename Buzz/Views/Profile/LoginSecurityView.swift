//
//  LoginSecurityView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct LoginSecurityView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        List {
            NavigationLink(destination: ChangePasswordView()) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Change Password")
                }
            }
            
            NavigationLink(destination: DeleteAccountView()) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .frame(width: 30)
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Login & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

