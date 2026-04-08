import Foundation

struct DayRecord: Codable, Identifiable {
    var id: String { date }
    let date: String  // "yyyy-MM-dd"
    var totalKeystrokes: Int
    var hourlyBuckets: [Int]  // 24 elements, index 0 = midnight hour

    static func empty(for date: String) -> DayRecord {
        DayRecord(date: date, totalKeystrokes: 0, hourlyBuckets: Array(repeating: 0, count: 24))
    }
}

struct StoreData: Codable {
    var records: [String: DayRecord]  // keyed by date string
}
