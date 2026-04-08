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

            // Today's key metrics
            HStack(spacing: 12) {
                StatCard(title: "Today", value: formatCount(tracker.todayCount), icon: "keyboard")
                StatCard(title: "Speed", value: "\(tracker.currentSpeed)", unit: "kpm", icon: "gauge.open.with.lines.needle.33percent")
                StatCard(title: "Streak", value: formatDuration(tracker.streakDuration), icon: "flame")
            }

            Divider()

            // Hourly activity
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Activity")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HourlyChartView(data: tracker.hourlyData)
                    .frame(height: 80)
            }

            Divider()

            // Week trend
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                WeekTrendView(data: tracker.weekData)
                    .frame(height: 60)
            }

            Divider()

            // Accessibility status + Quit
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
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            tracker.refreshStats()
        }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
