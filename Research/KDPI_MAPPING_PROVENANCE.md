# KDPI formula and mapping provenance

Research date: 2026-11-07

## Current calculation

The default calculator uses OPTN Policy 8.4.B's race- and HCV-neutral donor-only KDRI coefficients:

- age: `0.0092 × (age − 40)`, plus `0.0113 × (age − 18)` below age 18 or `0.0067 × (age − 50)` above age 50;
- creatinine: `0.2128 × (creatinine − 1)`, plus `−0.2199 × (creatinine − 1.5)` above 1.5 mg/dL; creatinine is capped at 8 mg/dL;
- hypertension `0.1106`, diabetes `0.2577`, CVA cause of death `0.0743`, and DCD `0.1966`;
- height `−0.0557 × (height − 170) / 10`;
- weight below 80 kg `−0.0333 × (weight − 80) / 5`.

Unknown hypertension and diabetes statuses use each mapping table's published reference-population prevalence. The summed linear predictor is exponentiated to produce RAO KDRI, divided by that release's scaling factor, then mapped to KDPI.

Primary sources:

- Current calculator and explanation: https://www.hrsa.gov/optn/data-calculators/allocation-calculators/kdpi-calculator
- Current calculation guide: https://www.hrsa.gov/sites/default/files/hrsa/optn/kdpi_guide.pdf
- Current OPTN policies: https://www.hrsa.gov/sites/default/files/hrsa/optn/optn-policies.pdf
- Oct. 31, 2024 policy implementation: https://www.hrsa.gov/optn/news-events/news/race-hepatitis-c-status-no-longer-included-calculation-used-estimate-deceased-donor-kidney-function

## Historical formula

Releases before Oct. 31, 2024 use the prior donor-only KDRI formula, including the published Black/African-American (`0.1790`) and HCV-positive (`0.2400`) terms. The complete coefficients are preserved in `KDPICalculator/KDPICalculator.swift` and verified against the archived OPTN guide and policy notice.

## Mapping releases

`kdpi_mapping_tables.json` contains 11 validated releases:

- annual reference populations 2016 through 2023 using the legacy formula;
- a separate Oct. 2024 refit using the 2023 reference population and new formula;
- the 2024 and 2025 annual reference populations using the new formula.

Every release stores 102 official interval upper bounds: one row each for KDPI 0–99 and two terminal KDPI 100 rows. It also stores scaling, unknown-value prevalences, formula version, database date, release position, and official source URL.

Archived tables: https://www.hrsa.gov/optn/data-calculators/allocation-calculators/archived-allocation-calculator-resources

The May 2025 annual PDF reused the generic current-table URL and was later overwritten by the 2026 annual release. Its 2024-reference bounds and metadata were recovered from the indexed official HRSA PDF before overwrite and are retained in `kdpi_2024_recovered.json`. Extracted public-source text snapshots are retained under `Research/source_text` so the catalog remains reproducible after HRSA rotates the generic URL.

## Validation rules

- exactly 102 rows per table;
- percentile sequence 0–99, 100, 100;
- strictly increasing and contiguous intervals;
- increasing release chronology, with a unique position for the Oct. 2024 refit;
- recognized formula version only;
- generated Swift must exactly match reviewed JSON;
- official Oct. 2024 worked example must return KDPI 79;
- current formula must be invariant to historical race/HCV flags.

## Interpretation limits

The Time Machine holds donor characteristics constant but intentionally does not hold KDRI constant. The underlying KDRI formula changed in October 2024, and each release also has its own scaling, prevalence assumptions, and mapping. This replay shows what the same recorded donor characteristics would have produced under each release; it does not estimate changing organ biology or a counterfactual transplant outcome.
