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

    private(set) var result = KDPICalculator.calculate(inputs: .example)

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
        result = KDPICalculator.calculate(inputs: inputs)
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
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    resultCard
                    inputCard
                    timeMachineLink
                    sourceFooter
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("KDPI Calculator")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("About KDPI")
                }
            }
            .sheet(isPresented: $showInfo) { informationSheet }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CURRENT KDPI")
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text("\(vm.result.percentile)%")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(vm.result.percentile))
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "kidney")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(scoreColor(vm.result.percentile))
                    .frame(width: 58, height: 58)
                    .background(scoreColor(vm.result.percentile).opacity(0.12), in: Circle())
            }

            Gauge(value: Double(vm.result.percentile), in: 0...100) { EmptyView() }
                .gaugeStyle(.linearCapacity)
                .tint(LinearGradient(colors: [.green, .teal, .orange, .red], startPoint: .leading, endPoint: .trailing))

            HStack {
                metric("Scaled KDRI", vm.result.scaledKDRI.formatted(.number.precision(.fractionLength(3))))
                Divider().frame(height: 34)
                metric("Reference", String(vm.result.mappingReferenceYear))
                Divider().frame(height: 34)
                metric("Formula", "2024 refit")
            }

            Text("Lower KDPI indicates lower estimated relative graft-failure risk in the reference population. It does not determine whether a kidney is suitable for a particular recipient.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Donor characteristics", systemImage: "list.clipboard.fill")
                .font(.headline)
                .padding(.bottom, 12)

            sliderRow("Age", value: $vm.age, range: 0...99, step: 1, valueText: "\(Int(vm.age)) yr")
            rowDivider
            sliderRow("Height", value: $vm.heightCM, range: 30...241, step: 1, valueText: "\(Int(vm.heightCM)) cm")
            rowDivider
            sliderRow("Weight", value: $vm.weightKG, range: 1...294, step: 1, valueText: "\(Int(vm.weightKG)) kg")
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
                }
                .padding(.top, 10)
            } label: {
                Text("Historical-only inputs").font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 7)
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
            Slider(value: value, in: range, step: step)
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
            KDPITimeMachineView(inputs: vm.inputs)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .background(.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("KDPI Time Machine").font(.headline).foregroundStyle(.primary)
                    Text("Same donor, 11 historical releases").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
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
                Section("What this calculates") {
                    Text("KDPI maps the donor-only KDRI to a percentile of the current OPTN deceased-donor reference population.")
                }
                Section("Important limits") {
                    Text("KDPI has moderate predictive power and should not be used by itself to accept or decline an organ offer. Verify any clinical or allocation use against DonorNet and current OPTN policy.")
                }
                Section("Current method") {
                    Text("The current calculation uses the race- and HCV-neutral KDRI formula implemented Oct. 31, 2024 and the latest published mapping table.")
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
