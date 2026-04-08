import Foundation

class KeystrokeStore {
    private let fileURL: URL

    var data: StoreData

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("BuddyCat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("keystroke_data.json")
        data = StoreData(records: [:])
        load()
    }

    func load() {
        guard let jsonData = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(StoreData.self, from: jsonData) {
            data = decoded
        }
    }

    func save() {
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: fileURL, options: .atomic)
    }

    func record(for date: String) -> DayRecord {
        data.records[date] ?? DayRecord.empty(for: date)
    }

    func updateRecord(_ record: DayRecord) {
        data.records[record.date] = record
    }

    func recentDays(_ count: Int) -> [DayRecord] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()

        return (0..<count).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today)!
            let key = formatter.string(from: date)
            return record(for: key)
        }
    }
}
