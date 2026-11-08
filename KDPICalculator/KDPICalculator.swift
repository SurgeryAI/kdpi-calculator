import Foundation

enum DonorHistoryStatus: String, CaseIterable, Identifiable, Sendable {
    case no = "No"
    case yes = "Yes"
    case unknown = "Unknown"

    var id: Self { self }

    func probability(whenUnknown prevalence: Double) -> Double {
        switch self {
        case .no: return 0
        case .yes: return 1
        case .unknown: return prevalence
        }
    }
}

struct KDPIDonorInputs: Equatable, Sendable {
    var age: Double
    var heightCM: Double
    var weightKG: Double
    var serumCreatinine: Double
    var hypertension: DonorHistoryStatus
    var diabetes: DonorHistoryStatus
    var cvaCauseOfDeath: Bool
    var dcd: Bool

    // Historical-only factors. The current formula deliberately ignores them.
    var blackOrAfricanAmerican: Bool
    var hcvPositive: Bool
}

struct KDPIResult: Equatable, Sendable {
    let percentile: Int
    let raoKDRI: Double
    let scaledKDRI: Double
    let mappingReferenceYear: Int
    let formulaVersion: KDRIFormulaVersion
}

struct KDPIHistoricalPoint: Identifiable, Sendable {
    let table: KDPIMappingTable
    let result: KDPIResult

    var id: String { table.id }
}

enum KDPICalculator {
    static func calculate(
        inputs: KDPIDonorInputs,
        mappingTable: KDPIMappingTable = KDPIMappingTables.current
    ) -> KDPIResult {
        validate(inputs)
        let rao = raoKDRI(
            inputs: inputs,
            formula: mappingTable.formulaVersion,
            diabetesPrevalence: mappingTable.diabetesPrevalence,
            hypertensionPrevalence: mappingTable.hypertensionPrevalence
        )
        let scaled = rao / mappingTable.scalingFactor
        return KDPIResult(
            percentile: mappingTable.percentile(for: scaled),
            raoKDRI: rao,
            scaledKDRI: scaled,
            mappingReferenceYear: mappingTable.referenceYear,
            formulaVersion: mappingTable.formulaVersion
        )
    }

    /// Recalculates the same donor characteristics with every contemporaneous
    /// formula, scaling factor, imputation prevalence, and percentile mapping.
    static func historicalResults(inputs: KDPIDonorInputs) -> [KDPIHistoricalPoint] {
        KDPIMappingTables.all.map { table in
            KDPIHistoricalPoint(table: table, result: calculate(inputs: inputs, mappingTable: table))
        }
    }

    static func raoKDRI(
        inputs: KDPIDonorInputs,
        formula: KDRIFormulaVersion,
        diabetesPrevalence: Double,
        hypertensionPrevalence: Double
    ) -> Double {
        let age = inputs.age.rounded(.down)
        let creatinine = min(inputs.serumCreatinine, 8)
        let diabetesProbability = inputs.diabetes.probability(whenUnknown: diabetesPrevalence)
        let hypertensionProbability = inputs.hypertension.probability(whenUnknown: hypertensionPrevalence)

        let linearPredictor: Double
        switch formula {
        case .legacyRaceHCV:
            linearPredictor =
                0.0128 * (age - 40)
                + (age < 18 ? -0.0194 * (age - 18) : 0)
                + (age > 50 ? 0.0107 * (age - 50) : 0)
                - 0.0464 * ((inputs.heightCM - 170) / 10)
                + (inputs.weightKG < 80 ? -0.0199 * ((inputs.weightKG - 80) / 5) : 0)
                + (inputs.blackOrAfricanAmerican ? 0.1790 : 0)
                + 0.1260 * hypertensionProbability
                + 0.1300 * diabetesProbability
                + (inputs.cvaCauseOfDeath ? 0.0881 : 0)
                + 0.2200 * (creatinine - 1)
                + (creatinine > 1.5 ? -0.2090 * (creatinine - 1.5) : 0)
                + (inputs.hcvPositive ? 0.2400 : 0)
                + (inputs.dcd ? 0.1330 : 0)

        case .raceHCVNeutral2024:
            linearPredictor =
                0.0092 * (age - 40)
                + (age < 18 ? 0.0113 * (age - 18) : 0)
                + (age > 50 ? 0.0067 * (age - 50) : 0)
                - 0.0557 * ((inputs.heightCM - 170) / 10)
                + (inputs.weightKG < 80 ? -0.0333 * ((inputs.weightKG - 80) / 5) : 0)
                + 0.1106 * hypertensionProbability
                + 0.2577 * diabetesProbability
                + (inputs.cvaCauseOfDeath ? 0.0743 : 0)
                + 0.2128 * (creatinine - 1)
                + (creatinine > 1.5 ? -0.2199 * (creatinine - 1.5) : 0)
                + (inputs.dcd ? 0.1966 : 0)
        }

        return exp(linearPredictor)
    }

    private static func validate(_ inputs: KDPIDonorInputs) {
        precondition(inputs.age.isFinite && (0...99).contains(inputs.age))
        precondition(inputs.heightCM.isFinite && (0...241.3).contains(inputs.heightCM))
        precondition(inputs.weightKG.isFinite && (0.454...294).contains(inputs.weightKG))
        precondition(inputs.serumCreatinine.isFinite && inputs.serumCreatinine > 0)
    }
}
