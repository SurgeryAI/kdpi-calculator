import SwiftUI

@Observable
@MainActor
final class KDPIViewModel {
    var age = 40.0 { didSet { recalculate() } }
    var heightCM = 170.0 { didSet { recalculate() } }
    var weightKG = 80.0 { didSet { recalculate() } }
    var serumCreatinine = 1.0 { didSet { recalculate() } }
    var hypertension = DonorHistoryStatus.no { didSet { recalculate() } }
    var diabetes = DonorHistoryStatus.no { didSet { recalculate() } }
    var cvaCauseOfDeath = false { didSet { recalculate() } }
    var dcd = false { didSet { recalculate() } }
    var blackOrAfricanAmerican = false { didSet { recalculate() } }
    var hcvPositive = false { didSet { recalculate() } }

    private(set) var result: KDPIResult?
    private(set) var inputError: KDPIInputError?

    init() {
        recalculate()
    }

    var inputs: KDPIDonorInputs {
        KDPIDonorInputs(
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            serumCreatinine: serumCreatinine,
            hypertension: hypertension,
            diabetes: diabetes,
            cvaCauseOfDeath: cvaCauseOfDeath,
            dcd: dcd,
            blackOrAfricanAmerican: blackOrAfricanAmerican,
            hcvPositive: hcvPositive
        )
    }

    private func recalculate() {
        do {
            result = try KDPICalculator.calculate(inputs: inputs)
            inputError = nil
        } catch {
            // Clear the previous score so invalid inputs never display a stale result.
            result = nil
            inputError = error
        }
    }
}

extension KDPIDonorInputs {
    static let example = KDPIDonorInputs(
        age: 40,
        heightCM: 170,
        weightKG: 80,
        serumCreatinine: 1,
        hypertension: .no,
        diabetes: .no,
        cvaCauseOfDeath: false,
        dcd: false,
        blackOrAfricanAmerican: false,
        hcvPositive: false
    )
}

struct ContentView: View {
    @State private var vm = KDPIViewModel()
    @State private var showHistoricalInputs = false
    @State private var historicalInputsConfirmed = false
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let result = vm.result {
                        CurrentKDPICard(percentile: result.percentile)
                    } else if let error = vm.inputError {
                        KDPIInputErrorView(error: error)
                    }
                    inputCard
                    timeMachineLink
                        .disabled(vm.result == nil)
                    sourceFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("KDPI Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("About KDPI")
                }
            }
            .sheet(isPresented: $showInfo) { informationSheet }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Donor characteristics", systemImage: "list.clipboard.fill")
                .font(.headline)
                .padding(.bottom, 12)

            sliderRow("Age", value: $vm.age, range: 0...99, step: 1, valueText: "\(vm.age.formatted(.number.precision(.fractionLength(0)))) yr")
            rowDivider
            sliderRow("Height", value: $vm.heightCM, range: 30...241, step: 1, valueText: "\(vm.heightCM.formatted(.number.precision(.fractionLength(0)))) cm")
            rowDivider
            sliderRow("Weight", value: $vm.weightKG, range: 1...294, step: 1, valueText: "\(vm.weightKG.formatted(.number.precision(.fractionLength(0)))) kg")
            rowDivider
            sliderRow("Serum creatinine", value: $vm.serumCreatinine, range: 0.1...12, step: 0.1, valueText: vm.serumCreatinine.formatted(.number.precision(.fractionLength(1))) + " mg/dL")
            Text("Values above 8 mg/dL are capped at 8 by the OPTN calculation.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 3)
            rowDivider
            statusRow("Hypertension history", selection: $vm.hypertension)
            rowDivider
            statusRow("Diabetes history", selection: $vm.diabetes)
            rowDivider
            Toggle("CVA cause of death", isOn: $vm.cvaCauseOfDeath).padding(.vertical, 7)
            rowDivider
            Toggle("Donation after circulatory death", isOn: $vm.dcd).padding(.vertical, 7)
            rowDivider

            DisclosureGroup(isExpanded: $showHistoricalInputs) {
                VStack(spacing: 8) {
                    Toggle("Black or African American donor", isOn: $vm.blackOrAfricanAmerican)
                    Toggle("HCV positive", isOn: $vm.hcvPositive)
                    Text("These factors are ignored by the current equity-improved formula. They are used only when replaying pre–Oct. 31, 2024 calculations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    Toggle(isOn: $historicalInputsConfirmed) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Historical values reviewed")
                            Text("Confirms the pre-refit results use the correct legacy values")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                Text("Historical-only inputs").font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 7)
            .onChange(of: vm.blackOrAfricanAmerican) { _, _ in
                historicalInputsConfirmed = false
            }
            .onChange(of: vm.hcvPositive) { _, _ in
                historicalInputsConfirmed = false
            }
        }
        .tint(.teal)
        .cardStyle()
    }

    private var rowDivider: some View { Divider().padding(.vertical, 6) }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(valueText).font(.subheadline.weight(.semibold)).foregroundStyle(.teal).monospacedDigit()
            }
            // Keep the control renderable even when an invalid value arrives externally.
            // The model retains that value and its error until the user adjusts the slider.
            Slider(value: Binding(
                get: {
                    guard value.wrappedValue.isFinite else { return range.lowerBound }
                    return min(max(value.wrappedValue, range.lowerBound), range.upperBound)
                },
                set: { value.wrappedValue = $0 }
            ), in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }

    private func statusRow(_ title: String, selection: Binding<DonorHistoryStatus>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline)
            Picker(title, selection: selection) {
                ForEach(DonorHistoryStatus.allCases) { status in Text(status.rawValue).tag(status) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var timeMachineLink: some View {
        NavigationLink {
            KDPITimeMachineView(inputs: timeMachineInputs)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .background(.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("KDPI Time Machine").font(.headline).foregroundStyle(.primary)
                    Text("Historical releases back to 2017")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
    }

    private var timeMachineInputs: KDPIDonorInputs {
        var inputs = vm.inputs
        inputs.historicalInputsConfirmed = historicalInputsConfirmed
        return inputs
    }

    private var sourceFooter: some View {
        VStack(spacing: 5) {
            Text("Current OPTN reference population: deceased kidney donors recovered in \(KDPIMappingTables.current.referenceYear).")
            Link("Open official HRSA/OPTN table", destination: URL(string: KDPIMappingTables.current.sourceURL)!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }

    private var informationSheet: some View {
        NavigationStack {
            List {
                Section {
                    Link(destination: URL(string: "https://transplanttools.com")!) {
                        HStack(spacing: 14) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(.teal.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Visit TransplantTools.com")
                                    .font(.headline)
                                Text("More transplant tools and resources")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .foregroundStyle(.teal)
                }
                Section("What this calculates") {
                    Text("KDPI maps the donor-only KDRI to a percentile of the current OPTN deceased-donor reference population.")
                }
                Section("Important limits") {
                    Text("KDPI has moderate predictive power and should not be used by itself to accept or decline an organ offer. Verify any clinical or allocation use against DonorNet and current OPTN policy.")
                }
                Section("Current method") {
                    Text("The current calculation uses the race- and HCV-neutral KDRI formula implemented Oct. 31, 2024 and the latest published mapping table.")
                }
                Section("Developer") {
                    Text("Developed by Marc L. Melcher, MD")
                }
            }
            .navigationTitle("About KDPI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showInfo = false } } }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case ...20: .green
        case 21...50: .teal
        case 51...85: .orange
        default: .red
        }
    }
}

private struct CurrentKDPICard: View {
    let percentile: Int
    @ScaledMetric(relativeTo: .title2) private var ringSize = 76

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 6)
                Circle()
                    .inset(by: 3)
                    .trim(from: 0, to: Double(percentile) / 100)
                    .stroke(.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(percentile)%")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(8)
            }
            .frame(width: ringSize, height: ringSize)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current KDPI")
                    .font(.headline)
                Text("Lower KDPI means lower relative graft-failure risk.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current KDPI")
        .accessibilityValue("\(percentile) percent")
        .accessibilityHint("Lower KDPI means lower relative graft-failure risk.")
    }
}

struct KDPIInputErrorView: View {
    let error: KDPIInputError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to calculate KDPI", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(error.message)
                .font(.subheadline)
            Text("Adjust the donor inputs to calculate again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            }
    }
}

#Preview { ContentView() }
