import Foundation

enum InputMethodType: String, Codable {
    case zh, en, other
}

struct KeyEvent {
    let timestamp: Date
    let keyCode: UInt16
    let isDelete: Bool
    let appName: String
    let inputMethod: InputMethodType
}

struct DayRecord: Codable, Identifiable {
    var id: String { date }
    let date: String  // "yyyy-MM-dd"
    var totalKeystrokes: Int
    var hourlyBuckets: [Int]  // 24 elements, index 0 = midnight hour
    var deleteCount: Int
    var appBreakdown: [String: Int]
    var inputMethodBreakdown: [String: Int]
    var longestSession: TimeInterval
    var sessionCount: Int

    static func empty(for date: String) -> DayRecord {
        DayRecord(
            date: date,
            totalKeystrokes: 0,
            hourlyBuckets: Array(repeating: 0, count: 24),
            deleteCount: 0,
            appBreakdown: [:],
            inputMethodBreakdown: [:],
            longestSession: 0,
            sessionCount: 0
        )
    }
}

extension DayRecord {
    enum CodingKeys: String, CodingKey {
        case date, totalKeystrokes, hourlyBuckets
        case deleteCount, appBreakdown, inputMethodBreakdown
        case longestSession, sessionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        totalKeystrokes = try container.decode(Int.self, forKey: .totalKeystrokes)
        hourlyBuckets = try container.decode([Int].self, forKey: .hourlyBuckets)
        deleteCount = try container.decodeIfPresent(Int.self, forKey: .deleteCount) ?? 0
        appBreakdown = try container.decodeIfPresent([String: Int].self, forKey: .appBreakdown) ?? [:]
        inputMethodBreakdown = try container.decodeIfPresent([String: Int].self, forKey: .inputMethodBreakdown) ?? [:]
        longestSession = try container.decodeIfPresent(TimeInterval.self, forKey: .longestSession) ?? 0
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
    }
}

struct StoreData: Codable {
    var records: [String: DayRecord]  // keyed by date string
}
