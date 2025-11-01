//
//  Config.example.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//
//  Instructions:
//  1. Copy this file and rename it to Config.swift
//  2. Replace the placeholder values with your actual credentials
//  3. DO NOT commit Config.swift to version control

import Foundation

struct Config {
    // Supabase Configuration
    // Get these from your Supabase project settings
    // URL: https://app.supabase.com/project/YOUR_PROJECT/settings/api
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-supabase-anon-key-here"
    
    // Google Sign-In Configuration
    // Get this from Google Cloud Console
    // URL: https://console.cloud.google.com/apis/credentials
    static let googleClientID = "your-google-client-id.apps.googleusercontent.com"
}

