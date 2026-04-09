# BuddyCat - Granular Input Statistics & Liquid Glass UI

**Date**: 2026-04-10
**Status**: Draft

## Overview

Enhance BuddyCat's keystroke tracking from simple key count to multi-dimensional input analytics: per-application breakdown, input method (Chinese/English) detection, delete rate tracking, and typing session/rhythm analysis. Redesign the stats popover UI with macOS 26 Liquid Glass.

## Goals

1. Track keystrokes per front-most application (app name granularity)
2. Detect current input method and classify as Chinese (`zh`), English (`en`), or other
3. Track delete key usage to compute a "modification rate"
4. Track typing session durations (continuous typing with < 3s gap)
5. Present all data passively in the stats popover (no push notifications)
6. Adopt macOS 26 Liquid Glass design throughout the popover UI

## Non-Goals

- Recording actual typed content (characters, words)
- Tracking per-document or per-tab activity (only app-level)
- Active break/RSI reminders or notifications
- Gamification or achievement systems

## Architecture

### Event-Driven Model (Collect then Aggregate)

Decouple raw event capture from statistical aggregation. `KeyEventMonitor` produces a `KeyEvent` struct per keystroke; `KeystrokeTracker` consumes it, maintains real-time stats in memory, and persists daily aggregates to `DayRecord`.

```
KeyEventMonitor (capture) --> KeyEvent --> KeystrokeTracker (aggregate) --> DayRecord (persist)
```

## Data Model

### KeyEvent (in-memory only, not persisted)

```swift
enum InputMethodType: String, Codable {
    case zh, en, other
}

struct KeyEvent {
    let timestamp: Date
    let keyCode: UInt16
    let isDelete: Bool        // keyCode 51 (Backspace) or 117 (Forward Delete)
    let appName: String       // NSWorkspace.shared.frontmostApplication?.localizedName
    let inputMethod: InputMethodType
}
```

### DayRecord (persisted to JSON)

```swift
struct DayRecord: Codable, Identifiable {
    var id: String { date }
    let date: String                        // "yyyy-MM-dd"
    var totalKeystrokes: Int
    var hourlyBuckets: [Int]                // 24 elements
    var deleteCount: Int                    // new
    var appBreakdown: [String: Int]         // new: {"VS Code": 3200, "Safari": 800}
    var inputMethodBreakdown: [String: Int] // new: {"zh": 2000, "en": 1800}
    var longestSession: TimeInterval        // new: longest continuous typing session (seconds)
    var sessionCount: Int                   // new: number of typing sessions in the day
}
```

**Backward compatibility**: New fields use `decodeIfPresent` with defaults (`0`, `[:]`). Existing `keystroke_data.json` files will load without error.

### StoreData (unchanged)

```swift
struct StoreData: Codable {
    var records: [String: DayRecord]
}
```

## Event Capture (KeyEventMonitor)

### Callback Signature Change

```swift
// Before
var onKeyDown: (() -> Void)?

// After
var onKeyDown: ((KeyEvent) -> Void)?
```

### Event Metadata Extraction

In both the NSEvent global monitor and CGEvent tap callbacks:

1. **keyCode**: `event.keyCode` (NSEvent) or `CGEvent.getIntegerValueField(.keyboardEventKeycode)` (CGEvent)
2. **isDelete**: `keyCode == 51 || keyCode == 117`
3. **appName**: `NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"`
4. **inputMethod**: Via `TISCopyCurrentKeyboardInputSource()` -> `kTISPropertyInputSourceID`

### Input Method Detection Logic

```swift
static func currentInputMethodType() -> InputMethodType {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
          let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? else {
        return .other
    }
    let lowered = id.lowercased()
    if lowered.contains("com.apple.keylayout") {
        return .en
    }
    let zhKeywords = ["chinese", "pinyin", "sogou", "baidu", "wechat", "shuangpin", "wubi", "zhuyin", "cangjie"]
    if zhKeywords.contains(where: { lowered.contains($0) }) {
        return .zh
    }
    return .other
}
```

**Known limitation**: Some third-party input methods handle Chinese/English switching internally without changing the system input source. Estimated accuracy: 85-95%.

## Statistical Aggregation (KeystrokeTracker)

### Method Change

```swift
// Before
func recordKeystroke()

// After
func recordEvent(_ event: KeyEvent)
```

### Real-Time Stats (in-memory)

| Property | Purpose |
|----------|---------|
| `recentEvents: [KeyEvent]` | Events in last 10 seconds, for speed calculation |
| `sessionStart: Date?` | Start of current continuous typing session |
| `lastEventTime: Date?` | Timestamp of last event, for session gap detection |
| `currentSessionDuration: TimeInterval` | Duration of current session |

### Per-Event Aggregation

On each `recordEvent(_:)`:

1. `totalKeystrokes += 1`
2. `hourlyBuckets[hour] += 1`
3. `appBreakdown[event.appName, default: 0] += 1`
4. `inputMethodBreakdown[event.inputMethod.rawValue, default: 0] += 1`
5. If `event.isDelete` -> `deleteCount += 1`
6. Session tracking: if gap since `lastEventTime` > 3s, finalize previous session (`sessionCount += 1`, update `longestSession`), start new session

### refreshStats() Additions

Computed on demand (not persisted):
- `deleteRate`: `deleteCount / totalKeystrokes` (percentage)
- `averageSpeed`: `totalKeystrokes / active hours count`

### Save Behavior

Unchanged: debounced save every 30 seconds after activity via `scheduleSave()`.

## UI Design (StatsPopoverView)

### Deployment Target

Raised from macOS 14.0 to macOS 26.0 to enable Liquid Glass APIs.

### Popover Layout

Width adjusted from 320pt to 340pt. Structure:

```
+------------------------------------------+
|  BuddyCat                         Stats  |  Header
+------------------------------------------+
| [GlassEffectContainer]                   |
|  [Today: 4.2k] [Speed: 86kpm] [Del: 8%] |  Row 1: Core metrics (3 StatCards)
+------------------------------------------+
|  App Breakdown          (clear glass bg) |  Row 2: Top 3 apps + "Other"
|  [VS Code 62%] [Safari 24%] [Other 14%] |  horizontal bar
+------------------------------------------+
|  Input Method           (clear glass bg) |  Row 3: zh/en ratio
|  [===zhzhzh===|==en==]  zh 58% en 42%   |  dual-color progress bar
+------------------------------------------+
|  Today's Activity                        |  Row 4: HourlyChartView (unchanged)
|  [hourly bar chart]                      |
+------------------------------------------+
|  This Week                               |  Row 5: WeekTrendView (unchanged)
|  [weekly bar chart]                      |
+------------------------------------------+
|  12 sessions, longest 28m                |  Row 6: Typing rhythm (text)
+------------------------------------------+
|  * Monitoring active              [Quit] |  Footer (glass bar)
+------------------------------------------+
```

### Liquid Glass Application

| Component | Glass Treatment |
|-----------|----------------|
| StatCard group (3 cards) | Wrapped in `GlassEffectContainer`. Each card: `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))`. Replaces existing `.background(.regularMaterial)` |
| App breakdown row | `.glassEffect(.clear)` background |
| Input method ratio bar | `.glassEffect(.clear)` background |
| Hourly / Weekly charts | No glass effect (avoid glass-on-glass nesting) |
| Footer status bar | `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))` |

### StatCard Changes

| Position | Before | After |
|----------|--------|-------|
| Card 1 | Today (keystroke count) | Today (keystroke count) - unchanged |
| Card 2 | Speed (KPM) | Speed (KPM) - unchanged |
| Card 3 | Streak (duration) | Modification Rate (delete %, icon: `delete.left`) |

Streak information moves to the typing rhythm row at the bottom.

### New Views

- **AppBreakdownView**: Horizontal stacked bar showing top 3 apps by keystroke count + "Other". Each segment labeled with app name and percentage.
- **InputMethodBarView**: Single horizontal bar, accent color for Chinese portion, secondary color for English, with percentage labels.

### Removed

- `StatCard` no longer uses `.background(.regularMaterial)` — replaced by `.glassEffect()`.

## Files Changed

| File | Change |
|------|--------|
| `BuddyCat.xcodeproj/project.pbxproj` | Deployment target -> macOS 26.0 |
| `Statistics/Models.swift` | Add `InputMethodType` enum, extend `DayRecord` with new fields, add backward-compatible decoding |
| `KeyMonitor/KeyEventMonitor.swift` | Callback signature change, extract keyCode/appName/inputMethod in monitors |
| `KeyMonitor/InputMethodHelper.swift` | **New file**: `InputMethodHelper` struct with `currentInputMethodType()` static method |
| `KeyMonitor/AccessibilityHelper.swift` | No changes |
| `Statistics/KeystrokeTracker.swift` | `recordEvent(_:)` replacing `recordKeystroke()`, session tracking, new computed stats |
| `Statistics/KeystrokeStore.swift` | No changes needed (generic encode/decode) |
| `App/AppDelegate.swift` | Update callback to pass `KeyEvent` |
| `MenuBar/StatusItemController.swift` | No logic changes, `animatePaw()` unchanged |
| `MenuBar/CatIconRenderer.swift` | No changes |
| `Views/StatsPopoverView.swift` | New layout with Liquid Glass, add modification rate card, app breakdown, input method bar, typing rhythm row |
| `Views/HourlyChartView.swift` | No changes |
| `Views/WeekTrendView.swift` | No changes |
| `Views/AppBreakdownView.swift` | **New file**: horizontal stacked bar for per-app stats |
| `Views/InputMethodBarView.swift` | **New file**: dual-color bar for zh/en ratio |

## Privacy

- No keystroke content is recorded — only keyCode (for delete detection), app name, and input method type
- All data remains local (`~/Library/Application Support/BuddyCat/`)
- No network access
