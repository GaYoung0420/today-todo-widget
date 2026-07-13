import Foundation

enum Formatters {
    static func timeRemaining(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let seconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func todoDateTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "오늘"
        }
        if calendar.isDateInTomorrow(date) {
            return "내일"
        }
        if calendar.isDateInYesterday(date) {
            return "어제"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 E"
        return formatter.string(from: date)
    }

    static func todoDateAccessibility(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter.string(from: date)
    }

    static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    static func clockHour(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        }
        if hour < 12 {
            return "\(hour) AM"
        }
        if hour == 12 {
            return "12 PM"
        }
        if hour < 24 {
            return "\(hour - 12) PM"
        }
        return "12 AM"
    }

    static func todoTimeRange(start: Date, end: Date?) -> String {
        guard let end else { return clockTime(start) }
        return "\(clockTime(start))-\(clockTime(end))"
    }
}
