import Foundation

enum FocusMusicTrack: String, CaseIterable, Identifiable, Codable {
    case feltHeartbeats
    case cedarCupJava

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feltHeartbeats:
            "Felt Heartbeats"
        case .cedarCupJava:
            "Cedar Cup Java"
        }
    }

    var resourceName: String {
        switch self {
        case .feltHeartbeats:
            "Felt Heartbeats"
        case .cedarCupJava:
            "Cedar Cup Java"
        }
    }

    var resourceExtension: String {
        "mp3"
    }
}
