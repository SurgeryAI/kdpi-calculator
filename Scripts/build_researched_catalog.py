#!/usr/bin/env python3
"""Build the reviewed historical KDPI catalog from extracted official tables."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from kdpi_mapping_tools import ReleaseMetadata, parse_table, validate_catalog, write_json


OFFICIAL = "https://www.hrsa.gov/sites/default/files/hrsa/optn/"

RELEASES = [
    ("2016", ReleaseMetadata(2016, "2017 annual", 2017, 2017.4, "2017-03-03", "legacyRaceHCV", OFFICIAL + "kdri-to-kdpi-mapping-table-2016.pdf")),
    ("2017", ReleaseMetadata(2017, "2018 annual", 2018, 2018.4, "2018-03-09", "legacyRaceHCV", OFFICIAL + "kdri-to-kdpi-mapping-table-2017.pdf")),
    ("2018", ReleaseMetadata(2018, "2019 annual", 2019, 2019.4, "2019-03-15", "legacyRaceHCV", OFFICIAL + "kdpi_mapping_table_2018.pdf")),
    ("2019", ReleaseMetadata(2019, "2020 annual", 2020, 2020.4, "2020-03-06", "legacyRaceHCV", OFFICIAL + "kdpi_mapping_table_2019.pdf")),
    ("2020", ReleaseMetadata(2020, "2021 annual", 2021, 2021.4, "2021-03-05", "legacyRaceHCV", OFFICIAL + "kdpi_mapping_table_2020.pdf")),
    ("2021", ReleaseMetadata(2021, "2022 annual", 2022, 2022.4, "2022-03-04", "legacyRaceHCV", OFFICIAL + "kdpi_mapping_table_2021.pdf")),
    ("2022", ReleaseMetadata(2022, "2023 annual", 2023, 2023.4, "2023-04-07", "legacyRaceHCV", OFFICIAL + "kdpi_mapping_table_2022.pdf")),
    ("2023", ReleaseMetadata(2023, "May 2024 annual", 2024, 2024.4, "2024-04-05", "legacyRaceHCV", OFFICIAL + "kdpi_mapping_table_2023.pdf")),
    ("2024-refit", ReleaseMetadata(2023, "Oct. 2024 refit", 2024, 2024.83, "2024-09-06", "raceHCVNeutral2024", OFFICIAL + "kdpi_mapping_table_2024.pdf")),
    ("current", ReleaseMetadata(2025, "2026 annual", 2026, 2026.4, "2026-04-03", "raceHCVNeutral2024", OFFICIAL + "kdpi_mapping_table.pdf")),
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--recovered-2024", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    parsed = []
    for filename, release in RELEASES[:-1]:
        text = (args.source_dir / f"kdpi-{filename}.txt").read_text(encoding="utf-8")
        parsed.append(parse_table(text, release))

    recovered = json.loads(args.recovered_2024.read_text(encoding="utf-8"))
    recovered.update({
        "releaseLabel": "May 2025 annual",
        "releaseYear": 2025,
        "timelinePosition": 2025.4,
        "formulaVersion": "raceHCVNeutral2024",
    })
    parsed.append(recovered)

    filename, release = RELEASES[-1]
    text = (args.source_dir / f"kdpi-{filename}.txt").read_text(encoding="utf-8")
    parsed.append(parse_table(text, release))

    write_json(args.output, validate_catalog(parsed))
    print(f"Wrote {len(parsed)} validated releases to {args.output}")


if __name__ == "__main__":
    main()
