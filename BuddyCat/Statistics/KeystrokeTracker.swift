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
    private(set) var hourlyData: [Int] = Array(repeating: 0, count: 24)
    private(set) var weekData: [DayRecord] = []
    private(set) var deleteCount: Int = 0
    private(set) var appBreakdown: [String: Int] = [:]
    private(set) var inputMethodBreakdown: [String: Int] = [:]
    private(set) var longestSession: TimeInterval = 0
    private(set) var sessionCount: Int = 0

    private var recentEvents: [KeyEvent] = []
    private var sessionStart: Date?
    private var lastEventTime: Date?
    private var saveTimer: Timer?
    private var currentDateString: String

    init() {
        currentDateString = dateFormatter.string(from: Date())
        loadToday()
    }

    func recordEvent(_ event: KeyEvent) {
        let now = event.timestamp
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

        // Per-app tracking
        appBreakdown[event.appName, default: 0] += 1

        // Input method tracking
        inputMethodBreakdown[event.inputMethod.rawValue, default: 0] += 1

        // Delete tracking
        if event.isDelete {
            deleteCount += 1
        }

        // Speed: events in last 10 seconds, extrapolated to per minute
        recentEvents.append(event)
        recentEvents.removeAll { now.timeIntervalSince($0.timestamp) > 10 }
        currentSpeed = recentEvents.count * 6

        // Session tracking: consecutive typing with < 3s gap
        if let last = lastEventTime, now.timeIntervalSince(last) < 3.0 {
            // Continue current session — no action needed
        } else {
            // Finalize previous session if it existed
            if let start = sessionStart, let last = lastEventTime {
                let duration = last.timeIntervalSince(start)
                if duration > 0 {
                    sessionCount += 1
                    if duration > longestSession {
                        longestSession = duration
                    }
                }
            }
            sessionStart = now
        }
        lastEventTime = now

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

        // Decay speed if no recent events
        if let last = lastEventTime, Date().timeIntervalSince(last) > 10 {
            currentSpeed = 0
        }
    }

    func save() {
        // Snapshot current session into longestSession before saving
        if let start = sessionStart, let last = lastEventTime {
            let duration = last.timeIntervalSince(start)
            if duration > longestSession {
                longestSession = duration
            }
        }

        let record = DayRecord(
            date: currentDateString,
            totalKeystrokes: todayCount,
            hourlyBuckets: hourlyData,
            deleteCount: deleteCount,
            appBreakdown: appBreakdown,
            inputMethodBreakdown: inputMethodBreakdown,
            longestSession: longestSession,
            sessionCount: sessionCount
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
        deleteCount = record.deleteCount
        appBreakdown = record.appBreakdown
        inputMethodBreakdown = record.inputMethodBreakdown
        longestSession = record.longestSession
        sessionCount = record.sessionCount
        weekData = store.recentDays(7)
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.save()
        }
    }
}
