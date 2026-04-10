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
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if zhCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor)
                                .frame(width: max(CGFloat(zhCount) / CGFloat(total) * geo.size.width - 1, 2))
                        }
                        if enCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: max(CGFloat(enCount) / CGFloat(total) * geo.size.width - 1, 2))
                        }
                        if otherCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: max(CGFloat(otherCount) / CGFloat(total) * geo.size.width - 1, 2))
                        }
                    }
                }
                .frame(height: 8)

                HStack(spacing: 12) {
                    if zhCount > 0 {
                        label(color: .accentColor, text: "中文 \(percentage(zhCount))%")
                    }
                    if enCount > 0 {
                        label(color: .secondary.opacity(0.5), text: "EN \(percentage(enCount))%")
                    }
                    if otherCount > 0 {
                        label(color: .secondary.opacity(0.3), text: "Other \(percentage(otherCount))%")
                    }
                    Spacer()
                }
            }
        }
    }

    private func label(color: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func percentage(_ count: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(round(Double(count) / Double(total) * 100))
    }
}
