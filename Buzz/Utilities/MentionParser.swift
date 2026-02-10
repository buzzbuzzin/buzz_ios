//
//  MentionParser.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/10/26.
//

import Foundation

struct MentionParser {

    /// Extract all @mentions from a text body.
    /// Returns callsigns without the @ prefix.
    static func extractMentions(from text: String) -> [String] {
        let pattern = "@([A-Za-z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    /// Find the current @mention being typed (for autocomplete trigger).
    /// Walks backwards from the end of text to find an active @ query.
    /// Returns the partial callsign after @, or nil if not in a mention.
    static func currentMentionQuery(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let chars = Array(text)
        var i = chars.count - 1

        // Walk backwards looking for @ or a whitespace/newline
        while i >= 0 {
            let ch = chars[i]
            if ch == "@" {
                // Found @, check it's at start or preceded by whitespace
                if i == 0 || chars[i - 1].isWhitespace || chars[i - 1].isNewline {
                    let start = text.index(text.startIndex, offsetBy: i + 1)
                    return String(text[start...])
                }
                return nil
            } else if ch.isWhitespace || ch.isNewline {
                return nil
            }
            i -= 1
        }
        return nil
    }

    /// Split text into segments of plain text and mentions for rich rendering.
    static func parseSegments(from text: String) -> [Segment] {
        let pattern = "@([A-Za-z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.plain(text)]
        }

        var segments: [Segment] = []
        var lastEnd = text.startIndex
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let callSignRange = Range(match.range(at: 1), in: text) else { continue }

            // Plain text before this mention
            if lastEnd < matchRange.lowerBound {
                segments.append(.plain(String(text[lastEnd..<matchRange.lowerBound])))
            }

            // The mention
            let callSign = String(text[callSignRange])
            segments.append(.mention(callSign))

            lastEnd = matchRange.upperBound
        }

        // Remaining text after last mention
        if lastEnd < text.endIndex {
            segments.append(.plain(String(text[lastEnd...])))
        }

        return segments
    }

    enum Segment {
        case plain(String)
        case mention(String)  // callSign without @
    }
}
