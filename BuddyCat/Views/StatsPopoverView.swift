import SwiftUI

struct StatsPopoverView: View {
    let tracker: KeystrokeTracker

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

            // Row 4: Hourly activity
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Activity")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HourlyChartView(data: tracker.hourlyData)
                    .frame(height: 80)
            }

            Divider()

            // Row 5: Week trend
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                WeekTrendView(data: tracker.weekData)
                    .frame(height: 60)
            }

            Divider()

            // Row 6: Typing rhythm
            HStack(spacing: 4) {
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

    private var deleteRateString: String {
        guard tracker.todayCount > 0 else { return "0%" }
        let rate = Double(tracker.deleteCount) / Double(tracker.todayCount) * 100
        return String(format: "%.0f%%", rate)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
}

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
