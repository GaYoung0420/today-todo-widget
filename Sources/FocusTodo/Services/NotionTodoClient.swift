import Foundation

struct NotionTodoClient {
    private let apiVersion = "2026-03-11"
    private let baseURL = URL(string: "https://api.notion.com/v1/")!

    func fetchTodos(
        token: String,
        databaseOrDataSourceID rawID: String,
        defaultPomodoroMinutes: Int,
        defaultBreakMinutes: Int
    ) async throws -> [TodoItem] {
        let inputID = try Self.normalizedIdentifier(rawID)
        let dataSourceID = try await resolveDataSourceID(token: token, inputID: inputID)
        let pages = try await queryAllPages(token: token, dataSourceID: dataSourceID)

        return pages.compactMap { page in
            mapPage(
                page,
                defaultPomodoroMinutes: defaultPomodoroMinutes,
                defaultBreakMinutes: defaultBreakMinutes
            )
        }
    }

    func upsertTodo(
        _ todo: TodoItem,
        token: String,
        databaseOrDataSourceID rawID: String
    ) async throws -> TodoItem {
        let schema = try await schema(token: token, databaseOrDataSourceID: rawID)
        let properties = propertiesPayload(for: todo, schema: schema)
        guard !properties.isEmpty else {
            throw NotionClientError.message("노션 DB에서 쓸 수 있는 속성을 찾지 못했습니다.")
        }

        let page: NotionPage
        if let pageID = todo.notionPageID {
            page = try await request(
                token: token,
                method: "PATCH",
                path: "pages/\(pageID)",
                body: NotionUpdatePageBody(properties: properties),
                responseType: NotionPage.self
            )
        } else {
            page = try await request(
                token: token,
                method: "POST",
                path: "pages",
                body: NotionCreatePageBody(
                    parent: NotionParent(dataSourceID: schema.dataSourceID),
                    properties: properties
                ),
                responseType: NotionPage.self
            )
        }

        var syncedTodo = todo
        syncedTodo.notionPageID = page.id
        syncedTodo.notionURL = page.url
        return syncedTodo
    }

    func archiveTodo(
        pageID: String,
        token: String
    ) async throws {
        _ = try await request(
            token: token,
            method: "PATCH",
            path: "pages/\(pageID)",
            body: NotionArchivePageBody(isArchived: true),
            responseType: NotionPage.self
        )
    }

    private func resolveDataSourceID(token: String, inputID: String) async throws -> String {
        do {
            _ = try await request(
                token: token,
                method: "GET",
                path: "data_sources/\(inputID)",
                body: Optional<EmptyBody>.none,
                responseType: NotionDataSourceResponse.self
            )
            return inputID
        } catch let error as NotionClientError {
            if !error.canFallbackToDatabaseLookup {
                throw error
            }
        }

        let database: NotionDatabaseResponse
        do {
            database = try await request(
                token: token,
                method: "GET",
                path: "databases/\(inputID)",
                body: Optional<EmptyBody>.none,
                responseType: NotionDatabaseResponse.self
            )
        } catch let error as NotionClientError {
            if error.isNotFound {
                throw NotionClientError.message(
                    "노션 DB를 찾을 수 없습니다. 원본 DB 우측 상단 메뉴에서 이 Integration을 Connections에 추가했는지, 같은 워크스페이스의 토큰인지 확인해주세요."
                )
            }
            throw error
        }

        guard let firstDataSourceID = database.dataSources.first?.id else {
            throw NotionClientError.message("노션 데이터베이스 안에서 data source를 찾지 못했습니다.")
        }
        return firstDataSourceID
    }

    private func queryAllPages(token: String, dataSourceID: String) async throws -> [NotionPage] {
        var pages: [NotionPage] = []
        var nextCursor: String?

        repeat {
            let response = try await request(
                token: token,
                method: "POST",
                path: "data_sources/\(dataSourceID)/query",
                body: NotionQueryBody(pageSize: 100, startCursor: nextCursor),
                responseType: NotionQueryResponse.self
            )
            pages.append(contentsOf: response.results)
            nextCursor = response.hasMore ? response.nextCursor : nil
        } while nextCursor != nil

        return pages
    }

    private func schema(token: String, databaseOrDataSourceID rawID: String) async throws -> NotionSyncSchema {
        let inputID = try Self.normalizedIdentifier(rawID)
        let dataSourceID = try await resolveDataSourceID(token: token, inputID: inputID)
        let dataSource = try await request(
            token: token,
            method: "GET",
            path: "data_sources/\(dataSourceID)",
            body: Optional<EmptyBody>.none,
            responseType: NotionDataSourceResponse.self
        )
        return NotionSyncSchema(dataSourceID: dataSourceID, properties: dataSource.properties)
    }

    private func request<Body: Encodable, Response: Decodable>(
        token: String,
        method: String,
        path: String,
        body: Body?,
        responseType: Response.Type
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw NotionClientError.message("노션 요청 URL을 만들지 못했습니다.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionClientError.message("노션 응답을 해석하지 못했습니다.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(NotionErrorResponse.self, from: data)
            throw NotionClientError.api(
                statusCode: httpResponse.statusCode,
                code: error?.code,
                message: error?.message
            )
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw NotionClientError.message("노션 데이터 형식이 예상과 다릅니다.")
        }
    }

    private func mapPage(
        _ page: NotionPage,
        defaultPomodoroMinutes: Int,
        defaultBreakMinutes: Int
    ) -> TodoItem? {
        guard let title = title(from: page.properties), !title.isEmpty else {
            return nil
        }

        let createdDate = page.createdTime ?? Date()
        let dateRange = todoDateRange(from: page.properties)
        let todoDate = dateRange?.date ?? createdDate
        let done = isDone(from: page.properties)
        let status = status(from: page.properties) ?? (done ? .completed : .notStarted)

        return TodoItem(
            title: title,
            notes: notes(from: page.properties),
            isDone: done || status == .completed,
            status: status,
            pomodoroMinutes: defaultPomodoroMinutes,
            breakMinutes: defaultBreakMinutes,
            targetPomodoros: targetPomodoros(from: page.properties),
            completedPomodoros: 0,
            createdAt: createdDate,
            todoDate: todoDate,
            scheduledStartAt: dateRange?.scheduledStartAt,
            scheduledEndAt: dateRange?.scheduledEndAt,
            notionPageID: page.id,
            notionURL: page.url
        )
    }

    private func title(from properties: [String: NotionPropertyValue]) -> String? {
        properties
            .first { $0.value.type == "title" }
            .map { plainText(from: $0.value.title) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func notes(from properties: [String: NotionPropertyValue]) -> String {
        let preferredNames = ["notes", "note", "memo", "description", "설명", "메모"]
        if let property = properties.first(where: { preferredNames.contains($0.key.lowercased()) })?.value {
            return plainText(from: property.richText)
        }

        return properties
            .first { $0.value.type == "rich_text" }
            .map { plainText(from: $0.value.richText) } ?? ""
    }

    private func isDone(from properties: [String: NotionPropertyValue]) -> Bool {
        let doneNames = ["done", "complete", "completed", "is done", "완료", "완료 여부"]

        for (name, property) in properties {
            let normalizedName = name.lowercased()
            if property.type == "checkbox", doneNames.contains(where: { normalizedName.contains($0) }) {
                return property.checkbox ?? false
            }

            if property.type == "status", doneNames.contains(where: { normalizedName.contains($0) }) {
                let status = property.status?.name.lowercased() ?? ""
                return status.contains("done") ||
                    status.contains("complete") ||
                    status.contains("완료")
            }
        }

        return false
    }

    private func status(from properties: [String: NotionPropertyValue]) -> TodoStatus? {
        let statusProperty = properties.first(where: { name, property in
                property.type == "status" &&
                    ["status", "상태", "done", "complete", "completed", "완료", "진행"]
                        .contains { name.lowercased().contains($0) }
            }) ?? properties.first { $0.value.type == "status" }

        guard let rawStatus = statusProperty?
            .value
            .status?
            .name
            .lowercased()
        else {
            return nil
        }

        if ["done", "complete", "completed", "완료"].contains(where: { rawStatus.contains($0) }) {
            return .completed
        }
        if ["in progress", "doing", "started", "진행", "시작중", "시작 중"].contains(where: { rawStatus.contains($0) }) {
            return .inProgress
        }
        if ["todo", "to do", "not started", "open", "backlog", "해야", "예정", "미완료", "시작 전", "시작전", "진행 전"].contains(where: { rawStatus.contains($0) }) {
            return .notStarted
        }

        return nil
    }

    private func targetPomodoros(from properties: [String: NotionPropertyValue]) -> Int {
        let targetNames = ["pomodoro", "target", "estimate", "뽀모도로", "예상"]
        for (name, property) in properties where property.type == "number" {
            if targetNames.contains(where: { name.lowercased().contains($0) }),
               let number = property.number {
                return max(Int(number), 1)
            }
        }
        return 4
    }

    private func todoDateRange(
        from properties: [String: NotionPropertyValue]
    ) -> (date: Date, scheduledStartAt: Date?, scheduledEndAt: Date?)? {
        guard let notionDate = notionDate(from: properties),
              let startDate = date(from: notionDate.start) else {
            return nil
        }

        let hasStartTime = Self.hasTimeComponent(notionDate.start)
        return (
            date: startDate,
            scheduledStartAt: hasStartTime ? startDate : nil,
            scheduledEndAt: hasStartTime ? date(from: notionDate.end) : nil
        )
    }

    private func notionDate(from properties: [String: NotionPropertyValue]) -> NotionDate? {
        let preferredNames = ["date", "due", "deadline", "schedule", "time", "날짜", "일자", "일정", "시간", "기한", "마감"]
        let preferredProperty = properties.first { name, property in
            property.type == "date" && preferredNames.contains { name.lowercased().contains($0) }
        }?.value

        if let date = preferredProperty?.date {
            return date
        }

        return properties
            .first { $0.value.type == "date" }
            .flatMap { $0.value.date }
    }

    private func date(from rawValue: String?) -> Date? {
        Self.parseNotionDate(rawValue)
    }

    private func plainText(from richTexts: [NotionRichText]?) -> String {
        richTexts?.map(\.plainText).joined() ?? ""
    }

    private func propertiesPayload(
        for todo: TodoItem,
        schema: NotionSyncSchema
    ) -> [String: NotionPropertyUpdate] {
        var payload: [String: NotionPropertyUpdate] = [:]

        if let titleName = schema.titlePropertyName {
            payload[titleName] = .title(todo.title)
        }

        if let notesName = schema.notesPropertyName {
            payload[notesName] = .richText(todo.notes)
        }

        if let dateName = schema.datePropertyName {
            payload[dateName] = .date(Self.notionDatePayload(for: todo))
        }

        if let doneName = schema.checkboxDonePropertyName {
            payload[doneName] = .checkbox(todo.isDone)
        }

        if let status = schema.statusProperty(for: todo.status) {
            payload[status.name] = .status(status.value)
        }

        if let targetName = schema.targetPomodorosPropertyName {
            payload[targetName] = .number(Double(todo.targetPomodoros))
        }

        return payload
    }

    private static func dateOnlyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func notionDatePayload(for todo: TodoItem) -> NotionDateValue {
        guard let scheduledStartAt = todo.scheduledStartAt else {
            return NotionDateValue(start: dateOnlyString(from: todo.todoDate), end: nil)
        }

        return NotionDateValue(
            start: dateTimeString(from: scheduledStartAt),
            end: todo.scheduledEndAt.map { dateTimeString(from: $0) }
        )
    }

    private static func dateTimeString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private static func hasTimeComponent(_ rawValue: String?) -> Bool {
        guard let rawValue else { return false }
        return rawValue.contains("T")
    }

    fileprivate static func parseNotionDate(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        let isoWithFractionalSeconds = ISO8601DateFormatter()
        isoWithFractionalSeconds.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = isoWithFractionalSeconds.date(from: rawValue) {
            return date
        }

        let isoWithoutFractionalSeconds = ISO8601DateFormatter()
        isoWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
        if let date = isoWithoutFractionalSeconds.date(from: rawValue) {
            return date
        }

        if let parsedDate = dateFormatters.lazy.compactMap({ $0.date(from: rawValue) }).first {
            return parsedDate
        }

        return dateOnlySubstring(from: rawValue)
            .flatMap { dateFormatter("yyyy-MM-dd").date(from: $0) }
    }

    private static var dateFormatters: [DateFormatter] {
        [
            dateFormatter("yyyy-MM-dd"),
            dateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"),
            dateFormatter("yyyy-MM-dd'T'HH:mm:ssXXXXX"),
            dateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
            dateFormatter("yyyy-MM-dd'T'HH:mm:ssZ")
        ]
    }

    private static func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    private static func dateOnlySubstring(from rawValue: String) -> String? {
        let pattern = #"\d{4}-\d{2}-\d{2}"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(rawValue.startIndex..<rawValue.endIndex, in: rawValue)
        guard let match = expression.firstMatch(in: rawValue, range: range),
              let matchRange = Range(match.range, in: rawValue) else {
            return nil
        }
        return String(rawValue[matchRange])
    }

    static func normalizedIdentifier(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NotionClientError.message("노션 DB URL 또는 ID를 입력해주세요.")
        }

        let dashedUUIDPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        if let match = firstMatch(pattern: dashedUUIDPattern, in: trimmed) {
            return match
        }

        let compactIDPattern = #"[0-9a-fA-F]{32}"#
        if let match = firstMatch(pattern: compactIDPattern, in: trimmed) {
            return match
        }

        throw NotionClientError.message("노션 DB URL 또는 ID 형식을 확인해주세요.")
    }

    private static func firstMatch(pattern: String, in value: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range),
              let matchRange = Range(match.range, in: value) else {
            return nil
        }
        return String(value[matchRange])
    }
}

enum NotionClientError: LocalizedError {
    case api(statusCode: Int, code: String?, message: String?)
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .api(statusCode, code, message):
            let detail = message ?? code ?? "알 수 없는 오류"
            return "노션 연동 실패(\(statusCode)): \(detail)"
        case let .message(message):
            return message
        }
    }

    var canFallbackToDatabaseLookup: Bool {
        switch self {
        case let .api(statusCode, _, _):
            return statusCode == 400 || statusCode == 404
        case .message:
            return false
        }
    }

    var isNotFound: Bool {
        switch self {
        case let .api(statusCode, _, _):
            return statusCode == 404
        case .message:
            return false
        }
    }
}

private struct EmptyBody: Encodable {}

private struct NotionErrorResponse: Decodable {
    let code: String?
    let message: String?
}

private struct NotionDatabaseResponse: Decodable {
    let dataSources: [NotionDataSourceSummary]

    enum CodingKeys: String, CodingKey {
        case dataSources = "data_sources"
    }
}

private struct NotionDataSourceSummary: Decodable {
    let id: String
}

private struct NotionDataSourceResponse: Decodable {
    let id: String
    let properties: [String: NotionDataSourceProperty]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        properties = try container.decodeIfPresent([String: NotionDataSourceProperty].self, forKey: .properties) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case id
        case properties
    }
}

private struct NotionDataSourceProperty: Decodable {
    let id: String?
    let name: String?
    let type: String
    let status: NotionStatusProperty?
}

private struct NotionStatusProperty: Decodable {
    let options: [NotionStatusOption]
}

private struct NotionStatusOption: Decodable {
    let name: String
}

private struct NotionSyncSchema {
    let dataSourceID: String
    let properties: [String: NotionDataSourceProperty]

    var titlePropertyName: String? {
        propertyName(type: "title")
    }

    var notesPropertyName: String? {
        preferredPropertyName(
            type: "rich_text",
            names: ["notes", "note", "memo", "description", "설명", "메모"]
        ) ?? propertyName(type: "rich_text")
    }

    var datePropertyName: String? {
        preferredPropertyName(
            type: "date",
            names: ["date", "due", "deadline", "schedule", "time", "날짜", "일자", "일정", "시간", "기한", "마감"]
        ) ?? propertyName(type: "date")
    }

    var checkboxDonePropertyName: String? {
        preferredPropertyName(
            type: "checkbox",
            names: ["done", "complete", "completed", "is done", "완료", "완료 여부"]
        ) ?? propertyName(type: "checkbox")
    }

    var targetPomodorosPropertyName: String? {
        preferredPropertyName(
            type: "number",
            names: ["pomodoro", "target", "estimate", "뽀모도로", "예상"]
        )
    }

    func statusProperty(for status: TodoStatus) -> (name: String, value: String)? {
        let statusProperty = properties.first { name, property in
            property.type == "status" &&
                ["done", "complete", "completed", "is done", "완료", "완료 여부", "status", "상태", "진행"]
                    .contains { name.lowercased().contains($0) }
        } ?? properties.first { $0.value.type == "status" }

        guard let propertyName = statusProperty?.key,
              let options = statusProperty?.value.status?.options else {
            return nil
        }

        if let option = options.first(where: { option in
            optionNames(for: status).contains { option.name.lowercased().contains($0) }
        }) {
            return (propertyName, option.name)
        }

        if status == .notStarted,
           let option = options.first(where: { option in
               !optionNames(for: .completed).contains { option.name.lowercased().contains($0) } &&
                   !optionNames(for: .inProgress).contains { option.name.lowercased().contains($0) }
           }) {
            return (propertyName, option.name)
        }

        return nil
    }

    private func optionNames(for status: TodoStatus) -> [String] {
        switch status {
        case .notStarted:
            return ["todo", "to do", "not started", "open", "backlog", "해야", "예정", "미완료", "시작 전", "시작전", "진행 전"]
        case .inProgress:
            return ["in progress", "doing", "started", "진행", "시작중", "시작 중"]
        case .completed:
            return ["done", "complete", "completed", "완료"]
        }
    }

    private func propertyName(type: String) -> String? {
        properties.first { $0.value.type == type }?.key
    }

    private func preferredPropertyName(type: String, names: [String]) -> String? {
        properties.first { name, property in
            property.type == type && names.contains { name.lowercased().contains($0) }
        }?.key
    }
}

private struct NotionCreatePageBody: Encodable {
    let parent: NotionParent
    let properties: [String: NotionPropertyUpdate]
}

private struct NotionUpdatePageBody: Encodable {
    let properties: [String: NotionPropertyUpdate]
}

private struct NotionArchivePageBody: Encodable {
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case isArchived = "is_archived"
    }
}

private struct NotionParent: Encodable {
    let type = "data_source_id"
    let dataSourceID: String

    enum CodingKeys: String, CodingKey {
        case type
        case dataSourceID = "data_source_id"
    }
}

private enum NotionPropertyUpdate: Encodable {
    case title(String)
    case richText(String)
    case checkbox(Bool)
    case status(String)
    case date(NotionDateValue)
    case number(Double)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .title(value):
            try container.encode([NotionTextValue(value)], forKey: .title)
        case let .richText(value):
            try container.encode([NotionTextValue(value)], forKey: .richText)
        case let .checkbox(value):
            try container.encode(value, forKey: .checkbox)
        case let .status(value):
            try container.encode(NotionNamedValue(name: value), forKey: .status)
        case let .date(value):
            try container.encode(value, forKey: .date)
        case let .number(value):
            try container.encode(value, forKey: .number)
        }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case richText = "rich_text"
        case checkbox
        case status
        case date
        case number
    }
}

private struct NotionTextValue: Encodable {
    let type = "text"
    let text: NotionTextContent

    init(_ content: String) {
        text = NotionTextContent(content: content)
    }
}

private struct NotionTextContent: Encodable {
    let content: String
}

private struct NotionNamedValue: Encodable {
    let name: String
}

private struct NotionDateValue: Encodable {
    let start: String
    let end: String?
}

private struct NotionQueryBody: Encodable {
    let pageSize: Int
    let startCursor: String?

    enum CodingKeys: String, CodingKey {
        case pageSize = "page_size"
        case startCursor = "start_cursor"
    }
}

private struct NotionQueryResponse: Decodable {
    let results: [NotionPage]
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

private struct NotionPage: Decodable {
    let id: String
    let url: String?
    let createdTime: Date?
    let properties: [String: NotionPropertyValue]

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case createdTime = "created_time"
        case properties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        properties = try container.decode([String: NotionPropertyValue].self, forKey: .properties)

        let createdTimeString = try container.decodeIfPresent(String.self, forKey: .createdTime)
        createdTime = NotionTodoClient.parseNotionDate(createdTimeString)
    }
}

private struct NotionPropertyValue: Decodable {
    let type: String
    let title: [NotionRichText]?
    let richText: [NotionRichText]?
    let checkbox: Bool?
    let status: NotionStatus?
    let number: Double?
    let date: NotionDate?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case richText = "rich_text"
        case checkbox
        case status
        case number
        case date
    }
}

private struct NotionRichText: Decodable {
    let plainText: String

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
    }
}

private struct NotionStatus: Decodable {
    let name: String
}

private struct NotionDate: Decodable {
    let start: String?
    let end: String?
}
