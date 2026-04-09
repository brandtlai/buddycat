# Granular Input Statistics & Liquid Glass UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance BuddyCat's keystroke tracking with per-app breakdown, input method detection, delete rate, session tracking, and a macOS 26 Liquid Glass UI.

**Architecture:** Event-driven model — `KeyEventMonitor` produces `KeyEvent` structs with metadata (keyCode, appName, inputMethod), `KeystrokeTracker` aggregates them into an extended `DayRecord`, UI views consume the aggregated stats. Liquid Glass applied to the popover's StatCards, breakdown bars, and footer.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Carbon (TIS APIs), macOS 26 Liquid Glass (`glassEffect`, `GlassEffectContainer`)

**Spec:** `docs/superpowers/specs/2026-04-10-granular-input-statistics-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `BuddyCat/Statistics/Models.swift` | Modify | Add `InputMethodType` enum, `KeyEvent` struct, extend `DayRecord` with new fields + backward-compatible decoding |
| `BuddyCat/KeyMonitor/InputMethodHelper.swift` | Create | `InputMethodHelper` struct with `currentInputMethodType()` using TIS APIs |
| `BuddyCat/KeyMonitor/KeyEventMonitor.swift` | Modify | Change callback to `(KeyEvent) -> Void`, extract metadata in monitors |
| `BuddyCat/Statistics/KeystrokeTracker.swift` | Modify | Replace `recordKeystroke()` with `recordEvent(_:)`, add session tracking, new published stats |
| `BuddyCat/App/AppDelegate.swift` | Modify | Build `KeyEvent` in callback, pass to `recordEvent(_:)` |
| `BuddyCat/Views/AppBreakdownView.swift` | Create | Horizontal stacked bar for per-app keystroke distribution |
| `BuddyCat/Views/InputMethodBarView.swift` | Create | Dual-color progress bar for zh/en input ratio |
| `BuddyCat/Views/StatsPopoverView.swift` | Modify | New layout with Liquid Glass, modification rate card, new breakdown views, typing rhythm row |
| `BuddyCat.xcodeproj/project.pbxproj` | Modify | Add new files to build target, raise deployment target to macOS 26.0 |

Files NOT changed: `AccessibilityHelper.swift`, `StatusItemController.swift`, `CatIconRenderer.swift`, `KeystrokeStore.swift`, `HourlyChartView.swift`, `WeekTrendView.swift`.

---

## Task 1: Data Models — InputMethodType, KeyEvent, DayRecord

**Files:**
- Modify: `BuddyCat/Statistics/Models.swift`

- [ ] **Step 1: Add InputMethodType enum and KeyEvent struct**

Add above the existing `DayRecord` struct in `Models.swift`:

```swift
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
```

- [ ] **Step 2: Extend DayRecord with new fields**

Replace the existing `DayRecord` with:

```swift
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
```

- [ ] **Step 3: Add backward-compatible Codable init**

Add a custom `init(from:)` to `DayRecord` so existing JSON files without the new fields still decode:

```swift
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
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project BuddyCat.xcodeproj -scheme BuddyCat build 2>&1 | tail -5`
Expected: Build will fail because `KeystrokeTracker` still calls `DayRecord` with the old init. This is expected — we fix it in Task 4.

- [ ] **Step 5: Commit**

```bash
git add BuddyCat/Statistics/Models.swift
git commit -m "feat(models): add InputMethodType, KeyEvent, extend DayRecord with new stats fields"
```

---

## Task 2: Input Method Detection Helper

**Files:**
- Create: `BuddyCat/KeyMonitor/InputMethodHelper.swift`

- [ ] **Step 1: Create InputMethodHelper**

Create `BuddyCat/KeyMonitor/InputMethodHelper.swift`:

```swift
import Carbon

struct InputMethodHelper {
    static func currentInputMethodType() -> InputMethodType {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return .other
        }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let lowered = id.lowercased()

        if lowered.contains("com.apple.keylayout") {
            return .en
        }

        let zhKeywords = [
            "chinese", "pinyin", "sogou", "baidu", "wechat",
            "shuangpin", "wubi", "zhuyin", "cangjie"
        ]
        if zhKeywords.contains(where: { lowered.contains($0) }) {
            return .zh
        }

        return .other
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Add `InputMethodHelper.swift` to the BuddyCat target in `project.pbxproj`. This can be done by opening Xcode or by manually editing the pbxproj. The simplest approach: open Xcode, right-click the `KeyMonitor` group, select "Add Files to BuddyCat", and select the new file.

Alternatively, if using CLI only, the file will be picked up if the Xcode project uses folder references. If it uses file references (this project does), you must add it via Xcode or edit `project.pbxproj`.

- [ ] **Step 3: Commit**

```bash
git add BuddyCat/KeyMonitor/InputMethodHelper.swift
git commit -m "feat(keymonitor): add InputMethodHelper for input source detection"
```

---

## Task 3: KeyEventMonitor — Extract Metadata

**Files:**
- Modify: `BuddyCat/KeyMonitor/KeyEventMonitor.swift`

- [ ] **Step 1: Change callback signature**

In `KeyEventMonitor.swift`, change line 10:

```swift
// Before
var onKeyDown: (() -> Void)?

// After
var onKeyDown: ((KeyEvent) -> Void)?
```

And update the `init`:

```swift
// Before
init(onKeyDown: @escaping () -> Void) {
    self.onKeyDown = onKeyDown
}

// After
init(onKeyDown: @escaping (KeyEvent) -> Void) {
    self.onKeyDown = onKeyDown
}
```

- [ ] **Step 2: Add a helper to build KeyEvent from keyCode**

Add a private method at the bottom of the `KeyEventMonitor` class:

```swift
private func buildKeyEvent(keyCode: UInt16) -> KeyEvent {
    KeyEvent(
        timestamp: Date(),
        keyCode: keyCode,
        isDelete: keyCode == 51 || keyCode == 117,
        appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown",
        inputMethod: InputMethodHelper.currentInputMethodType()
    )
}
```

- [ ] **Step 3: Update NSEvent global monitor callback**

In `setupNSEventGlobalMonitor()`, change the callback (line 74):

```swift
private func setupNSEventGlobalMonitor() {
    nsEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self else { return }
        let keyEvent = self.buildKeyEvent(keyCode: event.keyCode)
        NSLog("BuddyCat: GLOBAL NSEvent keyDown (key: \(event.keyCode))")
        self.onKeyDown?(keyEvent)
    }
    NSLog("BuddyCat: NSEvent global monitor: \(nsEventMonitor != nil ? "OK" : "FAILED")")
}
```

- [ ] **Step 4: Update local monitor callback**

In `setupMonitors()`, update the local monitor (line 65):

```swift
localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    guard let self else { return event }
    let keyEvent = self.buildKeyEvent(keyCode: event.keyCode)
    NSLog("BuddyCat: LOCAL keyDown detected (key: \(event.keyCode))")
    self.onKeyDown?(keyEvent)
    return event
}
```

- [ ] **Step 5: Commit**

```bash
git add BuddyCat/KeyMonitor/KeyEventMonitor.swift
git commit -m "feat(keymonitor): extract keyCode, appName, inputMethod into KeyEvent"
```

---

## Task 4: KeystrokeTracker — Event Aggregation & Session Tracking

**Files:**
- Modify: `BuddyCat/Statistics/KeystrokeTracker.swift`

- [ ] **Step 1: Add new stored properties**

Add new properties after the existing declarations (around line 16-17):

```swift
private(set) var deleteCount: Int = 0
private(set) var appBreakdown: [String: Int] = [:]
private(set) var inputMethodBreakdown: [String: Int] = [:]
private(set) var longestSession: TimeInterval = 0
private(set) var sessionCount: Int = 0
```

And rename/repurpose the session tracking properties. Replace the existing `streakStart`, `lastKeystroke` (lines 21-22) with:

```swift
private var sessionStart: Date?
private var lastEventTime: Date?
```

Remove `streakDuration` from stored properties (line 15). Remove `recentTimestamps` (line 19) and replace with:

```swift
private var recentEvents: [KeyEvent] = []
```

- [ ] **Step 2: Replace recordKeystroke() with recordEvent(_:)**

Replace the entire `recordKeystroke()` method (lines 30-61) with:

```swift
func recordEvent(_ event: KeyEvent) {
    let now = event.timestamp
    let todayStr = dateFormatter.string(from: now)

    // Handle midnight rollover
    if todayStr != currentDateString {
        save()
        currentDateString = todayStr
        loadToday()
    }

    totalKeystrokes += 1

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
        // Continue current session
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
        // Start new session
        sessionStart = now
    }
    lastEventTime = now

    scheduleSave()
}
```

- [ ] **Step 3: Update refreshStats()**

Replace the existing `refreshStats()` method (lines 65-78) with:

```swift
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
```

- [ ] **Step 4: Update save() to include new fields**

Replace the existing `save()` method (lines 80-89) with:

```swift
func save() {
    // Finalize current session before saving
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
```

- [ ] **Step 5: Update loadToday() to restore new fields**

Replace the existing `loadToday()` method (lines 91-99) with:

```swift
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
```

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild -project BuddyCat.xcodeproj -scheme BuddyCat build 2>&1 | tail -5`
Expected: Build will fail because `AppDelegate` still calls `recordKeystroke()`. Fixed in next task.

- [ ] **Step 7: Commit**

```bash
git add BuddyCat/Statistics/KeystrokeTracker.swift
git commit -m "feat(tracker): replace recordKeystroke with recordEvent, add session/app/inputMethod tracking"
```

---

## Task 5: AppDelegate — Wire Up KeyEvent

**Files:**
- Modify: `BuddyCat/App/AppDelegate.swift`

- [ ] **Step 1: Update the KeyEventMonitor callback**

Replace the `keyEventMonitor` initialization (lines 13-17) with:

```swift
keyEventMonitor = KeyEventMonitor { [weak self] keyEvent in
    NSLog("BuddyCat: onKeyDown callback invoked!")
    self?.keystrokeTracker.recordEvent(keyEvent)
    self?.statusItemController.animatePaw()
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project BuddyCat.xcodeproj -scheme BuddyCat build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED** — all compile errors from Tasks 1-4 should now be resolved.

- [ ] **Step 3: Commit**

```bash
git add BuddyCat/App/AppDelegate.swift
git commit -m "feat(appdelegate): wire KeyEvent through to recordEvent"
```

---

## Task 6: AppBreakdownView — Per-App Stats Bar

**Files:**
- Create: `BuddyCat/Views/AppBreakdownView.swift`

- [ ] **Step 1: Create AppBreakdownView**

Create `BuddyCat/Views/AppBreakdownView.swift`:

```swift
import SwiftUI

struct AppBreakdownView: View {
    let data: [String: Int]

    private var sortedApps: [(name: String, count: Int)] {
        let sorted = data.sorted { $0.value > $1.value }
        if sorted.count <= 3 {
            return sorted.map { (name: $0.key, count: $0.value) }
        }
        let top3 = sorted.prefix(3).map { (name: $0.key, count: $0.value) }
        let otherCount = sorted.dropFirst(3).reduce(0) { $0 + $1.value }
        return top3 + [(name: "Other", count: otherCount)]
    }

    private var total: Int {
        data.values.reduce(0, +)
    }

    var body: some View {
        if total == 0 {
            Text("No data yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Stacked horizontal bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(sortedApps, id: \.name) { app in
                            let fraction = CGFloat(app.count) / CGFloat(total)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: app.name))
                                .frame(width: max(fraction * geo.size.width - 1, 2))
                        }
                    }
                }
                .frame(height: 8)

                // Labels
                HStack(spacing: 8) {
                    ForEach(sortedApps, id: \.name) { app in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(color(for: app.name))
                                .frame(width: 6, height: 6)
                            Text("\(app.name) \(percentage(app.count))%")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private func percentage(_ count: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(round(Double(count) / Double(total) * 100))
    }

    private func color(for appName: String) -> Color {
        switch sortedApps.firstIndex(where: { $0.name == appName }) {
        case 0: return .accentColor
        case 1: return .blue.opacity(0.7)
        case 2: return .purple.opacity(0.6)
        default: return .secondary.opacity(0.4)
        }
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Add `AppBreakdownView.swift` to the BuddyCat target via Xcode (right-click Views group → Add Files).

- [ ] **Step 3: Commit**

```bash
git add BuddyCat/Views/AppBreakdownView.swift
git commit -m "feat(views): add AppBreakdownView for per-app keystroke distribution"
```

---

## Task 7: InputMethodBarView — Chinese/English Ratio Bar

**Files:**
- Create: `BuddyCat/Views/InputMethodBarView.swift`

- [ ] **Step 1: Create InputMethodBarView**

Create `BuddyCat/Views/InputMethodBarView.swift`:

```swift
import SwiftUI

struct InputMethodBarView: View {
    let data: [String: Int]

    private var zhCount: Int { data["zh"] ?? 0 }
    private var enCount: Int { data["en"] ?? 0 }
    private var otherCount: Int { data["other"] ?? 0 }
    private var total: Int { zhCount + enCount + otherCount }

    var body: some View {
        if total == 0 {
            Text("No data yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Dual-color bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if zhCount > 0 {
                            let zhFraction = CGFloat(zhCount) / CGFloat(total)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor)
                                .frame(width: max(zhFraction * geo.size.width - 1, 2))
                        }
                        if enCount > 0 {
                            let enFraction = CGFloat(enCount) / CGFloat(total)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: max(enFraction * geo.size.width - 1, 2))
                        }
                        if otherCount > 0 {
                            let otherFraction = CGFloat(otherCount) / CGFloat(total)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: max(otherFraction * geo.size.width - 1, 2))
                        }
                    }
                }
                .frame(height: 8)

                // Labels
                HStack(spacing: 12) {
                    if zhCount > 0 {
                        HStack(spacing: 3) {
                            Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                            Text("中文 \(percentage(zhCount))%")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if enCount > 0 {
                        HStack(spacing: 3) {
                            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                            Text("EN \(percentage(enCount))%")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if otherCount > 0 {
                        HStack(spacing: 3) {
                            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
                            Text("Other \(percentage(otherCount))%")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private func percentage(_ count: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(round(Double(count) / Double(total) * 100))
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Add `InputMethodBarView.swift` to the BuddyCat target via Xcode (right-click Views group → Add Files).

- [ ] **Step 3: Commit**

```bash
git add BuddyCat/Views/InputMethodBarView.swift
git commit -m "feat(views): add InputMethodBarView for Chinese/English input ratio"
```

---

## Task 8: StatsPopoverView — New Layout with Liquid Glass

**Files:**
- Modify: `BuddyCat/Views/StatsPopoverView.swift`

- [ ] **Step 1: Replace StatsPopoverView body**

Replace the entire `body` computed property in `StatsPopoverView` with:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 16) {
        // Header
        HStack {
            Text("BuddyCat")
                .font(.title3.bold())
            Spacer()
            Text("Stats")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        // Row 1: Core metrics with Liquid Glass
        GlassEffectContainer {
            HStack(spacing: 12) {
                StatCard(title: "Today", value: formatCount(tracker.todayCount), icon: "keyboard")
                StatCard(title: "Speed", value: "\(tracker.currentSpeed)", unit: "kpm", icon: "gauge.open.with.lines.needle.33percent")
                StatCard(title: "Del Rate", value: deleteRateString, icon: "delete.left")
            }
        }

        Divider()

        // Row 2: App breakdown
        VStack(alignment: .leading, spacing: 8) {
            Text("App Breakdown")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            AppBreakdownView(data: tracker.appBreakdown)
                .frame(height: 36)
                .padding(8)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 8))
        }

        Divider()

        // Row 3: Input method ratio
        VStack(alignment: .leading, spacing: 8) {
            Text("Input Method")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            InputMethodBarView(data: tracker.inputMethodBreakdown)
                .frame(height: 36)
                .padding(8)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 8))
        }

        Divider()

        // Row 4: Hourly activity (unchanged)
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Activity")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            HourlyChartView(data: tracker.hourlyData)
                .frame(height: 80)
        }

        Divider()

        // Row 5: Week trend (unchanged)
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            WeekTrendView(data: tracker.weekData)
                .frame(height: 60)
        }

        Divider()

        // Row 6: Typing rhythm
        HStack {
            Text("\(tracker.sessionCount) sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("longest \(formatDuration(tracker.longestSession))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }

        Divider()

        // Footer with glass
        HStack {
            Circle()
                .fill(AccessibilityHelper.hasPermission ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(AccessibilityHelper.hasPermission ? "Monitoring active" : "Need permission")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
    }
    .padding(20)
    .frame(width: 340)
    .onAppear {
        tracker.refreshStats()
    }
}
```

- [ ] **Step 2: Add deleteRateString computed property**

Add after the existing `formatDuration` method in `StatsPopoverView`:

```swift
private var deleteRateString: String {
    guard tracker.todayCount > 0 else { return "0%" }
    let rate = Double(tracker.deleteCount) / Double(tracker.todayCount) * 100
    return String(format: "%.0f%%", rate)
}
```

- [ ] **Step 3: Update StatCard to use Liquid Glass**

Replace the `StatCard` view's `body` property:

```swift
struct StatCard: View {
    let title: String
    let value: String
    var unit: String = ""
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -project BuddyCat.xcodeproj -scheme BuddyCat build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 5: Commit**

```bash
git add BuddyCat/Views/StatsPopoverView.swift
git commit -m "feat(views): redesign stats popover with Liquid Glass, app/inputMethod breakdown, delete rate"
```

---

## Task 9: Deployment Target & Xcode Project Cleanup

**Files:**
- Modify: `BuddyCat.xcodeproj/project.pbxproj`

- [ ] **Step 1: Raise deployment target to macOS 26.0**

In Xcode, select the BuddyCat project → Build Settings → Deployment Target → set macOS Deployment Target to `26.0`.

Or via command line:

```bash
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 14.0/MACOSX_DEPLOYMENT_TARGET = 26.0/g' BuddyCat.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Verify all new files are in the Xcode project**

Ensure these files are added to the BuddyCat target:
- `BuddyCat/KeyMonitor/InputMethodHelper.swift`
- `BuddyCat/Views/AppBreakdownView.swift`
- `BuddyCat/Views/InputMethodBarView.swift`

Open Xcode and check the file navigator. If any are missing, right-click the appropriate group → Add Files to "BuddyCat".

- [ ] **Step 3: Full build**

Run: `xcodebuild -project BuddyCat.xcodeproj -scheme BuddyCat build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Manual smoke test**

1. Run the app (Cmd+R in Xcode)
2. Grant Accessibility permission if prompted
3. Type in various apps (Terminal, Safari, etc.)
4. Click the cat icon in the menu bar
5. Verify:
   - Today count increments
   - Speed shows non-zero while typing
   - Del Rate shows percentage when using backspace
   - App Breakdown shows colored bar with app names
   - Input Method shows zh/en ratio (switch input methods to test)
   - Typing rhythm row shows session count and longest duration
   - Liquid Glass effects visible on StatCards, breakdown sections, footer
   - Hourly and Weekly charts still render correctly

- [ ] **Step 5: Commit**

```bash
git add BuddyCat.xcodeproj/project.pbxproj
git commit -m "chore: raise deployment target to macOS 26.0, add new files to project"
```

---

## Summary

| Task | What it does | Files |
|------|-------------|-------|
| 1 | Data models (InputMethodType, KeyEvent, DayRecord) | Models.swift |
| 2 | Input method detection helper | InputMethodHelper.swift (new) |
| 3 | KeyEventMonitor metadata extraction | KeyEventMonitor.swift |
| 4 | KeystrokeTracker aggregation + sessions | KeystrokeTracker.swift |
| 5 | AppDelegate wiring | AppDelegate.swift |
| 6 | App breakdown view | AppBreakdownView.swift (new) |
| 7 | Input method bar view | InputMethodBarView.swift (new) |
| 8 | Stats popover Liquid Glass redesign | StatsPopoverView.swift |
| 9 | Deployment target + project cleanup | project.pbxproj |
