import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    var isDone: Bool
    var pomodoroMinutes: Int
    var breakMinutes: Int
    var targetPomodoros: Int
    var completedPomodoros: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isDone: Bool = false,
        pomodoroMinutes: Int = 25,
        breakMinutes: Int = 5,
        targetPomodoros: Int = 4,
        completedPomodoros: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isDone = isDone
        self.pomodoroMinutes = pomodoroMinutes
        self.breakMinutes = breakMinutes
        self.targetPomodoros = targetPomodoros
        self.completedPomodoros = completedPomodoros
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case isDone
        case pomodoroMinutes
        case breakMinutes
        case targetPomodoros
        case completedPomodoros
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        pomodoroMinutes = try container.decodeIfPresent(Int.self, forKey: .pomodoroMinutes) ?? 25
        breakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5
        targetPomodoros = try container.decodeIfPresent(Int.self, forKey: .targetPomodoros) ?? 4
        completedPomodoros = try container.decodeIfPresent(Int.self, forKey: .completedPomodoros) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct AppState: Codable {
    var todos: [TodoItem]
    var blockedSites: [String]
    var defaultPomodoroMinutes: Int
    var defaultBreakMinutes: Int
    var launchAtLogin: Bool
    var notificationsEnabled: Bool
    var selectedFocusMusicID: String?
    var todoWidgetPosition: WidgetPosition?
    var isTodoWidgetPositionLocked: Bool

    static let initial = AppState(
        todos: [
            TodoItem(title: "첫 투두를 입력하세요", notes: "Command + M 으로 새 투두와 메모를 열 수 있습니다.")
        ],
        blockedSites: [
            "youtube.com",
            "instagram.com",
            "x.com",
            "twitter.com"
        ],
        defaultPomodoroMinutes: 25,
        defaultBreakMinutes: 5,
        launchAtLogin: false,
        notificationsEnabled: true,
        selectedFocusMusicID: nil,
        todoWidgetPosition: nil,
        isTodoWidgetPositionLocked: false
    )

    enum CodingKeys: String, CodingKey {
        case todos
        case blockedSites
        case defaultPomodoroMinutes
        case defaultBreakMinutes
        case launchAtLogin
        case notificationsEnabled
        case selectedFocusMusicID
        case todoWidgetPosition
        case isTodoWidgetPositionLocked
    }

    init(
        todos: [TodoItem],
        blockedSites: [String],
        defaultPomodoroMinutes: Int = 25,
        defaultBreakMinutes: Int = 5,
        launchAtLogin: Bool = false,
        notificationsEnabled: Bool = true,
        selectedFocusMusicID: String? = nil,
        todoWidgetPosition: WidgetPosition? = nil,
        isTodoWidgetPositionLocked: Bool = false
    ) {
        self.todos = todos
        self.blockedSites = blockedSites
        self.defaultPomodoroMinutes = defaultPomodoroMinutes
        self.defaultBreakMinutes = defaultBreakMinutes
        self.launchAtLogin = launchAtLogin
        self.notificationsEnabled = notificationsEnabled
        self.selectedFocusMusicID = selectedFocusMusicID
        self.todoWidgetPosition = todoWidgetPosition
        self.isTodoWidgetPositionLocked = isTodoWidgetPositionLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        blockedSites = try container.decodeIfPresent([String].self, forKey: .blockedSites) ?? []
        defaultPomodoroMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultPomodoroMinutes) ?? 25
        defaultBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultBreakMinutes) ?? 5
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        selectedFocusMusicID = try container.decodeIfPresent(String.self, forKey: .selectedFocusMusicID)
        todoWidgetPosition = try container.decodeIfPresent(WidgetPosition.self, forKey: .todoWidgetPosition)
        isTodoWidgetPositionLocked = try container.decodeIfPresent(Bool.self, forKey: .isTodoWidgetPositionLocked) ?? false
    }
}

struct WidgetPosition: Codable, Equatable {
    var x: Double
    var y: Double
}
