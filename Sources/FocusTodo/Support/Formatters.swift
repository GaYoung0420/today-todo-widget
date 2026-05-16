import Foundation

enum Formatters {
    static func timeRemaining(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let seconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
