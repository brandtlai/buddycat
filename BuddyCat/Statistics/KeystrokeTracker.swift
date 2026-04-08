import Foundation
import Observation

@Observable
class KeystrokeTracker {
    private let store = KeystrokeStore()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private(set) var todayCount: Int = 0
    private(set) var currentSpeed: Int = 0  // keys per minute
    private(set) var streakDuration: TimeInterval = 0
    private(set) var hourlyData: [Int] = Array(repeating: 0, count: 24)
    private(set) var weekData: [DayRecord] = []

    private var recentTimestamps: [Date] = []
    private var streakStart: Date?
    private var lastKeystroke: Date?
    private var saveTimer: Timer?
    private var currentDateString: String

    init() {
        currentDateString = dateFormatter.string(from: Date())
        loadToday()
    }

    func recordKeystroke() {
        let now = Date()
        let todayStr = dateFormatter.string(from: now)

        // Handle midnight rollover
        if todayStr != currentDateString {
            save()
            currentDateString = todayStr
            loadToday()
        }

        todayCount += 1

        let hour = Calendar.current.component(.hour, from: now)
        if hour < hourlyData.count {
            hourlyData[hour] += 1
        }

        // Speed: keystrokes in last 10 seconds, extrapolated to per minute
        recentTimestamps.append(now)
        recentTimestamps.removeAll { now.timeIntervalSince($0) > 10 }
        currentSpeed = recentTimestamps.count * 6

        // Streak: consecutive typing with < 3s gap
        if let last = lastKeystroke, now.timeIntervalSince(last) < 3.0 {
            streakDuration = now.timeIntervalSince(streakStart ?? now)
        } else {
            streakStart = now
            streakDuration = 0
        }
        lastKeystroke = now

        scheduleSave()
    }

    func refreshStats() {
        let todayStr = dateFormatter.string(from: Date())
        if todayStr != currentDateString {
            save()
            currentDateString = todayStr
            loadToday()
        }
        weekData = store.recentDays(7)

        // Decay speed if no recent keystrokes
        if let last = lastKeystroke, Date().timeIntervalSince(last) > 10 {
            currentSpeed = 0
        }
    }

    func save() {
        var record = store.record(for: currentDateString)
        record = DayRecord(
            date: currentDateString,
            totalKeystrokes: todayCount,
            hourlyBuckets: hourlyData
        )
        store.updateRecord(record)
        store.save()
    }

    private func loadToday() {
        let record = store.record(for: currentDateString)
        todayCount = record.totalKeystrokes
        hourlyData = record.hourlyBuckets
        if hourlyData.count != 24 {
            hourlyData = Array(repeating: 0, count: 24)
        }
        weekData = store.recentDays(7)
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.save()
        }
    }
}
