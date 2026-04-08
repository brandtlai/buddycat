import SwiftUI

struct WeekTrendView: View {
    let data: [DayRecord]

    var body: some View {
        let maxVal = max(data.map(\.totalKeystrokes).max() ?? 1, 1)

        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data) { record in
                    let fraction = CGFloat(record.totalKeystrokes) / CGFloat(maxVal)
                    let barHeight = max(fraction * (geo.size.height - 20), record.totalKeystrokes > 0 ? 2 : 0)
                    let isToday = record.date == currentDateString()

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isToday ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(height: barHeight)

                        Text(dayLabel(record.date))
                            .font(.system(size: 9))
                            .foregroundStyle(isToday ? .primary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func dayLabel(_ dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return "" }
        let weekday = Calendar.current.component(.weekday, from: date)
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday - 1]
    }
}
