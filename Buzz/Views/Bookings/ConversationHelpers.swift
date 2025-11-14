//
//  ConversationHelpers.swift
//  Buzz
//
//  Helper functions for conversation views
//

import Foundation

extension Date {
    func formattedConversationTime() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Today - show time
        if calendar.isDateInToday(self) {
            return self.formatted(date: .omitted, time: .shortened)
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // This week - show day name
        let daysAgo = calendar.dateComponents([.day], from: self, to: now).day ?? 0
        if daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name (Monday, Tuesday, etc.)
            return formatter.string(from: self)
        }
        
        // Older - show date
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: self)
    }
}

