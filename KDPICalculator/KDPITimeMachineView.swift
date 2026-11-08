import Charts
import SwiftUI

struct KDPITimeMachineView: View {
    private let points: [KDPIHistoricalPoint]
    private let minimum: Int
    private let maximum: Int
    private let current: KDPIHistoricalPoint?
    private let historicalInputsConfirmed: Bool
    private let legacyInputSummary: String
    private let inputError: KDPIInputError?

    init(inputs: KDPIDonorInputs) {
        let historicalInputsConfirmed = inputs.historicalInputsConfirmed
        let points: [KDPIHistoricalPoint]
        do {
            points = try KDPICalculator.historicalResults(inputs: inputs)
            self.inputError = nil
        } catch {
            points = []
            self.inputError = error
        }
        self.points = points
        self.minimum = points.map(\.result.percentile).min() ?? 0
        self.maximum = points.map(\.result.percentile).max() ?? 100
        self.current = points.last
        self.historicalInputsConfirmed = historicalInputsConfirmed
        self.legacyInputSummary = "Black/African American: \(inputs.blackOrAfricanAmerican ? "Yes" : "No") · HCV positive: \(inputs.hcvPositive ? "Yes" : "No")"
    }

    private var legacyTransition: KDPIHistoricalPoint? {
        points.last { $0.table.formulaVersion == .legacyRaceHCV }
    }

    private var refitTransition: KDPIHistoricalPoint? {
        points.first { $0.table.formulaVersion == .raceHCVNeutral2024 }
    }

    private var xDomain: ClosedRange<Double> {
        let positions = points.map(\.table.timelinePosition)
        guard let first = positions.min(), let last = positions.max() else {
            return 0...1
        }
        return (first - 0.45)...(last + 0.55)
    }

    private var xAxisPositions: [Double] {
        let positions = points.map(\.table.timelinePosition).sorted()
        guard positions.count > 5 else { return positions }

        // Keep labels readable on an iPhone while preserving the formula transition.
        let sampled = [0.0, 0.3, 0.6, 1.0].map { fraction in
            let offset = Int((fraction * Double(positions.count - 1)).rounded())
            return positions[offset]
        }
        let refit = refitTransition?.table.timelinePosition
        return Array(Set(sampled + [refit].compactMap { $0 })).sorted()
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
                if let inputError {
                    KDPIInputErrorView(error: inputError)
                } else {
                    explanationCard
                    chartCard
                    releaseHistory
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("KDPI Time Machine")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Same donor, different releases")
                        .font(.headline)
                    Text("Fixed characteristics recalculated with each OPTN method")
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

            if historicalInputsConfirmed {
                Label(legacyInputSummary, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Label("Pre-refit points use the legacy values shown above. Review those values on the calculator for an accurate replay.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
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
                Label("Lower is better", systemImage: "arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Release", point.table.timelinePosition),
                        y: .value("KDPI", point.result.percentile),
                        series: .value("Formula", point.table.formulaVersion.rawValue)
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

                if let current {
                    PointMark(
                        x: .value("Current release", current.table.timelinePosition),
                        y: .value("Current KDPI", current.result.percentile)
                    )
                    .symbolSize(0)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.indigo)
                    }
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
            .chartLegend(.hidden)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: xAxisPositions) { value in
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

            if let legacyTransition, let refitTransition {
                HStack(spacing: 8) {
                    Text("\(legacyTransition.result.percentile)%")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                    Text("\(refitTransition.result.percentile)%")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Text("Formula changed Oct. 31, 2024")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
            }
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
    NavigationStack {
        KDPITimeMachineView(inputs: .example)
    }
}
