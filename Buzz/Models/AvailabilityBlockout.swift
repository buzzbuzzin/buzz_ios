//
//  AvailabilityBlockout.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

enum RecurrenceType: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Every Day"
        case .weekly: return "Every Week"
        case .weekdays: return "Every Weekday"
        case .weekends: return "Every Weekend"
        case .monthly: return "Every Month"
        }
    }
}

struct AvailabilityBlockout: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let label: String?
    let startDate: Date
    let endDate: Date
    let recurrenceType: RecurrenceType
    let recurrenceEndDate: Date? // Optional end date for recurrence
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case label
        case startDate = "start_date"
        case endDate = "end_date"
        case recurrenceType = "recurrence_type"
        case recurrenceEndDate = "recurrence_end_date"
        case createdAt = "created_at"
    }
    
    // Check if a given date/time falls within this blockout
    func contains(date: Date) -> Bool {
        let calendar = Calendar.current
        
        // For non-recurring blockouts
        if recurrenceType == .none {
            return date >= startDate && date <= endDate
        }
        
        // For recurring blockouts, check if the date matches the pattern
        guard let recurrenceEndDate = recurrenceEndDate else {
            // If no end date, recur indefinitely
            return matchesRecurrencePattern(date: date)
        }
        
        // Check if date is before recurrence end
        guard date <= recurrenceEndDate else {
            return false
        }
        
        // Check if date matches the recurrence pattern
        return matchesRecurrencePattern(date: date)
    }
    
    private func matchesRecurrencePattern(date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch recurrenceType {
        case .none:
            return date >= startDate && date <= endDate
            
        case .daily:
            // Check if date is on or after start date and time matches
            guard date >= calendar.startOfDay(for: startDate) else {
                return false
            }
            return matchesTimeRange(date: date)
            
        case .weekly:
            // Check if date is on or after start date, day of week matches, and time matches
            guard date >= calendar.startOfDay(for: startDate) else {
                return false
            }
            let startWeekday = calendar.component(.weekday, from: startDate)
            let dateWeekday = calendar.component(.weekday, from: date)
            
            if startWeekday == dateWeekday {
                return matchesTimeRange(date: date)
            }
            return false
            
        case .weekdays:
            // Check if date is on or after start date, is a weekday, and time matches
            guard date >= calendar.startOfDay(for: startDate) else {
                return false
            }
            // Monday = 2, Friday = 6
            let weekday = calendar.component(.weekday, from: date)
            if weekday >= 2 && weekday <= 6 {
                return matchesTimeRange(date: date)
            }
            return false
            
        case .weekends:
            // Check if date is on or after start date, is a weekend, and time matches
            guard date >= calendar.startOfDay(for: startDate) else {
                return false
            }
            // Saturday = 7, Sunday = 1
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 {
                return matchesTimeRange(date: date)
            }
            return false
            
        case .monthly:
            // Check if date is on or after start date, day of month matches, and time matches
            guard date >= calendar.startOfDay(for: startDate) else {
                return false
            }
            let startDay = calendar.component(.day, from: startDate)
            let dateDay = calendar.component(.day, from: date)
            
            if startDay == dateDay {
                return matchesTimeRange(date: date)
            }
            return false
        }
    }
    
    private func matchesTimeRange(date: Date) -> Bool {
        let calendar = Calendar.current
        let startTime = calendar.dateComponents([.hour, .minute], from: startDate)
        let endTime = calendar.dateComponents([.hour, .minute], from: endDate)
        let dateTime = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let dateHour = dateTime.hour, let dateMinute = dateTime.minute,
              let startHour = startTime.hour, let startMinute = startTime.minute,
              let endHour = endTime.hour, let endMinute = endTime.minute else {
            return false
        }
        
        let dateMinutes = dateHour * 60 + dateMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        return dateMinutes >= startMinutes && dateMinutes <= endMinutes
    }
}

