import SwiftUI

struct HourlyChartView: View {
    let data: [Int]

    var body: some View {
        let maxVal = max(data.max() ?? 1, 1)
        let currentHour = Calendar.current.component(.hour, from: Date())

        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(0..<24, id: \.self) { hour in
                    let fraction = CGFloat(data[hour]) / CGFloat(maxVal)
                    let barHeight = max(fraction * (geo.size.height - 16), data[hour] > 0 ? 2 : 0)

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(hour == currentHour ? Color.accentColor : Color.secondary.opacity(0.5))
                            .frame(height: barHeight)

                        if hour % 6 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        } else {
                            Spacer().frame(height: 10)
                        }
                    }
                }
            }
        }
    }
}
