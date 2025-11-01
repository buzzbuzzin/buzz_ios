//
//  SupabaseClient.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import Supabase

class SupabaseClient {
    static let shared = SupabaseClient()
    
    let client: Supabase.SupabaseClient
    
    private init() {
        self.client = Supabase.SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
}

