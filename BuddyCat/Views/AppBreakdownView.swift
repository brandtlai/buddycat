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
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(sortedApps, id: \.name) { app in
                            let fraction = CGFloat(app.count) / CGFloat(total)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(segmentColor(for: app.name))
                                .frame(width: max(fraction * geo.size.width - 1, 2))
                        }
                    }
                }
                .frame(height: 8)

                HStack(spacing: 8) {
                    ForEach(sortedApps, id: \.name) { app in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(segmentColor(for: app.name))
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

    private func segmentColor(for appName: String) -> Color {
        switch sortedApps.firstIndex(where: { $0.name == appName }) {
        case 0: return .accentColor
        case 1: return .blue.opacity(0.7)
        case 2: return .purple.opacity(0.6)
        default: return .secondary.opacity(0.4)
        }
    }
}
