# BuddyCat

A macOS menu bar app that tracks your keyboard activity with an animated cat. The cat "paws" left and right with each keystroke, and clicking the icon shows your typing statistics.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Animated cat icon in the menu bar that reacts to your keystrokes
- Real-time typing speed (keys per minute)
- Typing streak tracking
- Hourly keystroke chart (24-hour view)
- Weekly trend chart (7-day view)
- Data persisted locally as JSON

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/brandtlai/buddycat.git
cd buddycat
```

### 2. Open in Xcode

```bash
open BuddyCat.xcodeproj
```

### 3. Configure signing

In Xcode, select the **BuddyCat** target → **Signing & Capabilities** → change **Team** to your own Apple ID (free account works).

### 4. Build & Run

Press **Cmd + R**. The cat icon will appear in your menu bar.

### 5. Grant Accessibility permission

BuddyCat needs Accessibility permission to detect keystrokes.

On first launch, you'll be prompted to grant access:

**System Settings → Privacy & Security → Accessibility → Enable BuddyCat**

If you don't see the prompt, the app will keep checking every 2 seconds until permission is granted.

## How It Works

- **Menu bar icon**: The cat alternates between idle, left-paw, and right-paw frames as you type
- **Click the cat**: Opens a popover with your typing stats
- **Data storage**: Keystroke data is saved to `~/Library/Application Support/BuddyCat/keystroke_data.json`
- **No network**: All data stays on your machine. Nothing is sent anywhere.

## Project Structure

```
BuddyCat/
├── BuddyCatApp.swift              # App entry point
├── App/
│   └── AppDelegate.swift          # Initializes core systems
├── KeyMonitor/
│   ├── KeyEventMonitor.swift      # Keystroke detection
│   └── AccessibilityHelper.swift  # Permission handling
├── MenuBar/
│   ├── StatusItemController.swift # Menu bar icon & popover
│   └── CatIconRenderer.swift      # Cat animation frames
├── Statistics/
│   ├── Models.swift               # Data models
│   ├── KeystrokeTracker.swift     # Live stats tracking
│   └── KeystrokeStore.swift       # JSON persistence
├── Views/
│   ├── StatsPopoverView.swift     # Stats popover UI
│   ├── HourlyChartView.swift      # 24-hour chart
│   └── WeekTrendView.swift        # 7-day trend chart
└── Resources/
    ├── cat_idle.png
    ├── cat_left.png
    └── cat_right.png
```

## License

MIT
