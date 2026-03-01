//
//  CallSignValidator.swift
//  Buzz
//

import Foundation

struct CallSignValidator {

    /// Returns an error message if the call sign matches the user's real name, else nil.
    /// Only enforced for name components >= 3 characters to avoid false positives on short names.
    static func realNameViolation(callSign: String, firstName: String, lastName: String) -> String? {
        let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let first = firstName.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCallSign.isEmpty else { return nil }

        var blocked = Set<String>()

        if first.count >= 3 {
            blocked.insert(first)
        }
        if last.count >= 3 {
            blocked.insert(last)
        }
        if !first.isEmpty && !last.isEmpty {
            let firstLast = first + last
            if firstLast.count >= 3 {
                blocked.insert(firstLast)
            }
            let lastFirst = last + first
            if lastFirst.count >= 3 {
                blocked.insert(lastFirst)
            }
        }

        if blocked.contains(normalizedCallSign) {
            return "Your call sign cannot be your real name"
        }

        return nil
    }
}
