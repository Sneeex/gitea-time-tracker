import Foundation

public enum SmartTimeParser {
    /// Parses natural text inputs like "1h 30m", "45m", "1.5h", "90", "01:15" into total seconds.
    public static func parseToSeconds(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // Format 1: pure number (assumed as minutes if > 0, e.g. "45" => 45 minutes = 2700s)
        if let totalMinutes = Int(trimmed) {
            return max(0, totalMinutes * 60)
        }

        // Format 2: decimal hours e.g. "1.5h" or "1,5h"
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let decimalPattern = #"^([0-9]+(?:\.[0-9]+)?)\s*h$"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)),
           let range = Range(match.range(at: 1), in: normalized),
           let hours = Double(normalized[range]) {
            return max(0, Int(hours * 3600.0))
        }

        // Format 3: "HH:MM" or "HH:MM:SS"
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                let hours = parts[0]
                let mins = parts[1]
                return max(0, (hours * 3600) + (mins * 60))
            } else if parts.count == 3 {
                let hours = parts[0]
                let mins = parts[1]
                let secs = parts[2]
                return max(0, (hours * 3600) + (mins * 60) + secs)
            }
        }

        // Format 4: Combination of Xh Ym Zs (e.g., "1h 30m 15s" or "45m" or "2h")
        var totalSecs = 0
        var matched = false

        let hourPattern = #"([0-9]+)\s*h"#
        let minPattern = #"([0-9]+)\s*m"#
        let secPattern = #"([0-9]+)\s*s"#

        if let hRegex = try? NSRegularExpression(pattern: hourPattern),
           let match = hRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)),
           let range = Range(match.range(at: 1), in: trimmed),
           let h = Int(trimmed[range]) {
            totalSecs += h * 3600
            matched = true
        }

        if let mRegex = try? NSRegularExpression(pattern: minPattern),
           let match = mRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)),
           let range = Range(match.range(at: 1), in: trimmed),
           let m = Int(trimmed[range]) {
            totalSecs += m * 60
            matched = true
        }

        if let sRegex = try? NSRegularExpression(pattern: secPattern),
           let match = sRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)),
           let range = Range(match.range(at: 1), in: trimmed),
           let s = Int(trimmed[range]) {
            totalSecs += s
            matched = true
        }

        return matched ? totalSecs : nil
    }

    /// Formats seconds into HH:MM:SS string (e.g. 3665 -> "01:01:05")
    public static func formatTimerString(_ seconds: Int) -> String {
        let secs = max(0, seconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let remainingSeconds = secs % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }

    /// Formats seconds into natural string (e.g. 5400 -> "1h 30m")
    public static func formatHumanReadable(_ seconds: Int) -> String {
        let secs = max(0, seconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let remainingSeconds = secs % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}
