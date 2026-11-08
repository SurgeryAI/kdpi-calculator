import Foundation

@main
struct VerifyKDPILogic {
    static func main() throws {
        let officialExample = KDPIDonorInputs(
            age: 52,
            heightCM: 183,
            weightKG: 81,
            serumCreatinine: 1.7,
            hypertension: .yes,
            diabetes: .no,
            cvaCauseOfDeath: true,
            dcd: true,
            blackOrAfricanAmerican: false,
            hcvPositive: false
        )
        guard let refit2023 = KDPIMappingTables.all.first(where: { $0.releaseLabel == "Oct. 2024 refit" }) else {
            fatalError("Missing Oct. 2024 refit table")
        }
        let exampleResult = try KDPICalculator.calculate(inputs: officialExample, mappingTable: refit2023)
        requireClose(exampleResult.raoKDRI, 1.71235565748184, tolerance: 1e-12, "official example RAO KDRI")
        requireClose(exampleResult.scaledKDRI, 1.3081317836685, tolerance: 1e-12, "official example scaled KDRI")
        precondition(exampleResult.percentile == 79, "Official example must map to KDPI 79")

        var historicalFlags = officialExample
        historicalFlags.blackOrAfricanAmerican = true
        historicalFlags.hcvPositive = true
        let currentWithoutFlags = try KDPICalculator.calculate(inputs: officialExample)
        let currentWithFlags = try KDPICalculator.calculate(inputs: historicalFlags)
        requireClose(currentWithoutFlags.raoKDRI, currentWithFlags.raoKDRI, tolerance: 0, "current formula ignores race and HCV")

        guard let legacy = KDPIMappingTables.all.first(where: { $0.formulaVersion == .legacyRaceHCV }) else {
            fatalError("Missing legacy table")
        }
        let legacyWithoutFlags = try KDPICalculator.calculate(inputs: officialExample, mappingTable: legacy)
        let legacyWithFlags = try KDPICalculator.calculate(inputs: historicalFlags, mappingTable: legacy)
        precondition(legacyWithFlags.raoKDRI > legacyWithoutFlags.raoKDRI, "Legacy formula must apply race and HCV coefficients")

        let table = KDPIMappingTables.current
        precondition(table.upperBounds.count == 102)
        precondition(table.percentile(for: table.upperBounds[0]) == 0)
        precondition(table.percentile(for: table.upperBounds[0].nextUp) == 1)
        precondition(table.percentile(for: .infinity) == 100)
        precondition(KDPIMappingTables.all.count == 11)

        print("KDPI formula, current mapping, historical replay, and official worked example verified")
    }

    private static func requireClose(_ actual: Double, _ expected: Double, tolerance: Double, _ label: String) {
        precondition(abs(actual - expected) <= tolerance, "\(label): \(actual) != \(expected)")
    }
}
