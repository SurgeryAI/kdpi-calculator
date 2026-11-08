import Foundation
import Testing
@testable import KDPICore

private func donor() -> KDPIDonorInputs {
    KDPIDonorInputs(
        age: 52, heightCM: 183, weightKG: 81, serumCreatinine: 1.7,
        hypertension: .yes, diabetes: .no, cvaCauseOfDeath: true,
        dcd: true, blackOrAfricanAmerican: false, hcvPositive: false
    )
}

@Test(arguments: [Double.nan, .infinity, -.infinity, -1, 100])
func invalidAge(value: Double) {
    var inputs = donor()
    inputs.age = value
    expectRejection(inputs, error: .invalidAge)
}

@Test(arguments: [Double.nan, .infinity, -.infinity, -1, 242])
func invalidHeight(value: Double) {
    var inputs = donor()
    inputs.heightCM = value
    expectRejection(inputs, error: .invalidHeight)
}

@Test(arguments: [Double.nan, .infinity, -.infinity, 0, 0.453, 295])
func invalidWeight(value: Double) {
    var inputs = donor()
    inputs.weightKG = value
    expectRejection(inputs, error: .invalidWeight)
}

@Test(arguments: [Double.nan, .infinity, -.infinity, 0, -1])
func invalidCreatinine(value: Double) {
    var inputs = donor()
    inputs.serumCreatinine = value
    expectRejection(inputs, error: .invalidCreatinine)
}

private func expectRejection(_ inputs: KDPIDonorInputs, error: KDPIInputError) {
    #expect(throws: error) { try KDPICalculator.calculate(inputs: inputs) }
    #expect(throws: error) { try KDPICalculator.historicalResults(inputs: inputs) }
}

@Test func validBoundariesAndCreatinineCap() throws {
    var inputs = donor()
    for age in [0.0, 99] {
        for height in [0.0, 241.3] {
            for weight in [0.454, 294] {
                inputs.age = age
                inputs.heightCM = height
                inputs.weightKG = weight
                let result = try KDPICalculator.calculate(inputs: inputs)
                #expect(result.raoKDRI.isFinite)
                #expect((0...100).contains(result.percentile))
            }
        }
    }
    inputs = donor()
    inputs.serumCreatinine = 8
    let capped = try KDPICalculator.calculate(inputs: inputs)
    inputs.serumCreatinine = 12
    #expect(try KDPICalculator.calculate(inputs: inputs) == capped)
}

@Test func officialExampleAndRecovery() throws {
    var inputs = donor()
    let table = try #require(KDPIMappingTables.all.first { $0.releaseLabel == "Oct. 2024 refit" })
    let result = try KDPICalculator.calculate(inputs: inputs, mappingTable: table)
    #expect(abs(result.raoKDRI - 1.71235565748184) < 1e-12)
    #expect(abs(result.scaledKDRI - 1.3081317836685) < 1e-12)
    #expect(result.percentile == 79)
    inputs.serumCreatinine = .nan
    expectRejection(inputs, error: .invalidCreatinine)
    inputs.serumCreatinine = 1.7
    #expect(try KDPICalculator.calculate(inputs: inputs, mappingTable: table) == result)
    #expect(try KDPICalculator.historicalResults(inputs: inputs).count == KDPIMappingTables.all.count)
}
