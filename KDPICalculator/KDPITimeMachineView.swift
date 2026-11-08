import Charts
import SwiftUI

struct KDPITimeMachineView: View {
    private let points: [KDPIHistoricalPoint]
    private let minimum: Int
    private let maximum: Int
    private let current: KDPIHistoricalPoint?
    private let usesLegacyFactors: Bool

    init(inputs: KDPIDonorInputs) {
        let points = KDPICalculator.historicalResults(inputs: inputs)
        self.points = points
        self.minimum = points.map(\.result.percentile).min() ?? 0
        self.maximum = points.map(\.result.percentile).max() ?? 100
        self.current = points.last
        self.usesLegacyFactors = inputs.blackOrAfricanAmerican || inputs.hcvPositive
    }

    private var yDomain: ClosedRange<Double> {
        let spread = maximum - minimum
        let padding = max(3, Int(ceil(Double(spread) * 0.3)))
        let lower = max(0, minimum - padding)
        let upper = min(100, max(maximum + padding, lower + 8))
        return Double(lower)...Double(upper)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                explanationCard
                chartCard
                releaseHistory
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("KDPI Time Machine")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Same donor characteristics")
                        .font(.headline)
                    Text("Recalculated under each historical release")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let current {
                    Text("\(current.result.percentile)%")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.indigo)
                        .monospacedDigit()
                }
            }

            Text("This is not the donor aging over time. Age, height, weight, creatinine, and clinical flags stay fixed. Each point applies that release’s KDRI formula, unknown-value assumptions, scaling factor, and KDPI mapping.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if usesLegacyFactors {
                Label("Race and/or HCV affects releases before Oct. 31, 2024 only.", systemImage: "info.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("KDPI by release").font(.headline)
                    Text("Range \(minimum)%–\(maximum)% · spread \(maximum - minimum) points")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Lower").font(.caption.weight(.semibold)).foregroundStyle(.green)
                    Text("estimated risk").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Release", point.table.timelinePosition),
                        y: .value("KDPI", point.result.percentile)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(.teal)

                    PointMark(
                        x: .value("Release", point.table.timelinePosition),
                        y: .value("KDPI", point.result.percentile)
                    )
                    .symbolSize(point.id == current?.id ? 100 : 48)
                    .foregroundStyle(point.id == current?.id ? .indigo : .teal)
                    .accessibilityLabel(point.table.releaseLabel)
                    .accessibilityValue("KDPI \(point.result.percentile) percent")
                }

                RuleMark(x: .value("Formula refit", 2024.83))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.indigo.opacity(0.7))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Formula refit")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.indigo)
                    }
            }
            .chartXScale(domain: 2016.8...2026.65)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: [2017.4, 2019.4, 2021.4, 2023.4, 2024.83, 2026.4]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let position = value.as(Double.self) {
                            Text(axisLabel(position))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let score = value.as(Int.self) { Text("\(score)%") }
                    }
                }
            }
            .frame(height: 260)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .cardStyle()
    }

    private func axisLabel(_ position: Double) -> String {
        if abs(position - 2024.83) < 0.1 { return "Oct ’24" }
        return String(Int(position.rounded(.down)))
    }

    private var releaseHistory: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Historical releases", systemImage: "tablecells")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(points) { point in
                releaseRow(point)
                if point.id != points.last?.id { Divider() }
            }
        }
        .cardStyle()
    }

    private func releaseRow(_ point: KDPIHistoricalPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.table.releaseLabel).font(.subheadline.weight(.semibold))
                    Text("\(point.table.referenceYear) donor reference · \(point.table.formulaVersion.shortLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("\(point.result.percentile)%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(point.id == current?.id ? .indigo : .teal)
                    .monospacedDigit()
            }

            HStack {
                Text("KDRI \(point.result.scaledKDRI.formatted(.number.precision(.fractionLength(3))))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = URL(string: point.table.sourceURL) {
                    Link("Official PDF", destination: url)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack { KDPITimeMachineView(inputs: .example) }
}
