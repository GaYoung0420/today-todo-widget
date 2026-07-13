import Foundation

enum TodoStatus: String, Codable, Equatable {
    case notStarted
    case inProgress
    case completed
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    var isDone: Bool
    var status: TodoStatus
    var pomodoroMinutes: Int
    var breakMinutes: Int
    var targetPomodoros: Int
    var completedPomodoros: Int
    var createdAt: Date
    var todoDate: Date
    var scheduledStartAt: Date?
    var scheduledEndAt: Date?
    var notionPageID: String?
    var notionURL: String?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isDone: Bool = false,
        status: TodoStatus? = nil,
        pomodoroMinutes: Int = 25,
        breakMinutes: Int = 5,
        targetPomodoros: Int = 4,
        completedPomodoros: Int = 0,
        createdAt: Date = Date(),
        todoDate: Date? = nil,
        scheduledStartAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        notionPageID: String? = nil,
        notionURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isDone = isDone
        self.status = status ?? (isDone ? .completed : .notStarted)
        self.pomodoroMinutes = pomodoroMinutes
        self.breakMinutes = breakMinutes
        self.targetPomodoros = targetPomodoros
        self.completedPomodoros = completedPomodoros
        self.createdAt = createdAt
        self.todoDate = todoDate ?? createdAt
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.notionPageID = notionPageID
        self.notionURL = notionURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case isDone
        case status
        case pomodoroMinutes
        case breakMinutes
        case targetPomodoros
        case completedPomodoros
        case createdAt
        case todoDate
        case scheduledStartAt
        case scheduledEndAt
        case notionPageID
        case notionURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        status = try container.decodeIfPresent(TodoStatus.self, forKey: .status) ?? (isDone ? .completed : .notStarted)
        pomodoroMinutes = try container.decodeIfPresent(Int.self, forKey: .pomodoroMinutes) ?? 25
        breakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5
        targetPomodoros = try container.decodeIfPresent(Int.self, forKey: .targetPomodoros) ?? 4
        completedPomodoros = try container.decodeIfPresent(Int.self, forKey: .completedPomodoros) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        todoDate = try container.decodeIfPresent(Date.self, forKey: .todoDate) ?? createdAt
        scheduledStartAt = try container.decodeIfPresent(Date.self, forKey: .scheduledStartAt)
        scheduledEndAt = try container.decodeIfPresent(Date.self, forKey: .scheduledEndAt)
        notionPageID = try container.decodeIfPresent(String.self, forKey: .notionPageID)
        notionURL = try container.decodeIfPresent(String.self, forKey: .notionURL)
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
    var isTodoWidgetDesktopModeEnabled: Bool
    var notionEnabled: Bool
    var notionDatabaseID: String
    var notionLastSyncedAt: Date?
    var notionAutoSyncEnabled: Bool
    var notionAutoSyncIntervalSeconds: Int
    var notionSyncMessage: String

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
        isTodoWidgetPositionLocked: false,
        isTodoWidgetDesktopModeEnabled: true,
        notionEnabled: false,
        notionDatabaseID: "",
        notionLastSyncedAt: nil,
        notionAutoSyncEnabled: true,
        notionAutoSyncIntervalSeconds: 60,
        notionSyncMessage: ""
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
        case isTodoWidgetDesktopModeEnabled
        case notionEnabled
        case notionDatabaseID
        case notionLastSyncedAt
        case notionAutoSyncEnabled
        case notionAutoSyncIntervalSeconds
        case notionSyncMessage
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
        isTodoWidgetPositionLocked: Bool = false,
        isTodoWidgetDesktopModeEnabled: Bool = true,
        notionEnabled: Bool = false,
        notionDatabaseID: String = "",
        notionLastSyncedAt: Date? = nil,
        notionAutoSyncEnabled: Bool = true,
        notionAutoSyncIntervalSeconds: Int = 60,
        notionSyncMessage: String = ""
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
        self.isTodoWidgetDesktopModeEnabled = isTodoWidgetDesktopModeEnabled
        self.notionEnabled = notionEnabled
        self.notionDatabaseID = notionDatabaseID
        self.notionLastSyncedAt = notionLastSyncedAt
        self.notionAutoSyncEnabled = notionAutoSyncEnabled
        self.notionAutoSyncIntervalSeconds = notionAutoSyncIntervalSeconds
        self.notionSyncMessage = notionSyncMessage
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
        isTodoWidgetDesktopModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTodoWidgetDesktopModeEnabled) ?? true
        notionEnabled = try container.decodeIfPresent(Bool.self, forKey: .notionEnabled) ?? false
        notionDatabaseID = try container.decodeIfPresent(String.self, forKey: .notionDatabaseID) ?? ""
        notionLastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .notionLastSyncedAt)
        notionAutoSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .notionAutoSyncEnabled) ?? true
        notionAutoSyncIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .notionAutoSyncIntervalSeconds) ?? 60
        notionSyncMessage = try container.decodeIfPresent(String.self, forKey: .notionSyncMessage) ?? ""
    }
}

struct WidgetPosition: Codable, Equatable {
    var x: Double
    var y: Double
}
