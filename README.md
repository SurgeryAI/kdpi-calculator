# KDPI Calculator

A SwiftUI iPhone calculator for the OPTN Kidney Donor Profile Index (KDPI), with a historical Time Machine that recalculates the same deceased-donor characteristics under prior KDRI formulas and annual KDPI mappings.

## What is included

- Current race- and HCV-neutral KDRI formula implemented by OPTN on Oct. 31, 2024.
- Current official KDPI mapping based on the 2025 deceased-donor reference population.
- Eleven release points spanning 2017–2026, including both the May 2024 legacy release and the Oct. 2024 refit.
- Historical-only race and HCV inputs, explicitly ignored by the current formula.
- Weekly GitHub Actions surveillance that validates a newly published official table and opens a review PR.

## Verification

Run the Swift Testing validation and calculation regression suite with `swift test`.

```sh
python3 Scripts/generate_kdpi_mapping_data.py \
  --catalog Research/kdpi_mapping_tables.json \
  --output KDPICalculator/KDPIMappingTables.swift \
  --check

swiftc \
  KDPICalculator/KDPIMappingTables.swift \
  KDPICalculator/KDPICalculator.swift \
  Scripts/verify_kdpi_logic.swift \
  -o /tmp/verify-kdpi-logic
/tmp/verify-kdpi-logic
```

The logic test reproduces the official OPTN worked example: RAO KDRI 1.71235565748184, scaled KDRI 1.3081317836685, and KDPI 79 under the Oct. 2024 refit table.

## Update design

The app never fetches clinical calculation data at runtime. Reviewed mapping releases are pinned in JSON and generated into Swift, keeping startup and input interactions local and deterministic.

The scheduled workflow checks the current HRSA PDF every Monday. It fails closed on malformed rows, discontinuities, same-year changes, skipped years, or logic-test failures. A valid new annual table is proposed as an unmerged pull request. Human review must also confirm whether OPTN changed the KDRI formula; the automation never guesses a new clinical formula.

## Intended use

Educational and decision-support reference only. KDPI has moderate predictive power and is not sufficient by itself to accept or decline an organ. Verify clinical and allocation decisions against DonorNet and current OPTN policy.
