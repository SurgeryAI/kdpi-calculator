#!/usr/bin/env python3
"""Parse and validate official OPTN KDRI-to-KDPI mapping-table text."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


TABLE_TOKEN_RE = re.compile(
    r"(?P<percent>(?:100|[1-9]?\d)%)|"
    r"(?P<number>(?<![\d.])\d+(?:\.\d+)?(?![\d.]))"
)


@dataclass(frozen=True)
class ReleaseMetadata:
    reference_year: int
    release_label: str
    release_year: int
    timeline_position: float
    database_as_of: str
    formula_version: str
    source_url: str


def parse_rows(text: str) -> list[dict[str, float | int]]:
    """Parse row-, five-column-, and vertical-layout PDF text extractions."""
    table_end = re.search(r"Minimum \(scaled\) KDRI observed", text, re.IGNORECASE)
    first_percentile = re.search(r"(?:-->|–>)\s*0%", text)
    if not first_percentile or not table_end or first_percentile.start() >= table_end.start():
        raise ValueError("Could not locate the KDPI table body")

    table_start = text.rfind("\n", 0, first_percentile.start()) + 1
    body = re.sub(
        r"\b\d+\s*\(continued\)|>\s*<=\s*KDPI is",
        " ",
        text[table_start : table_end.start()],
        flags=re.IGNORECASE,
    )
    body = re.sub(
        r"\b\d{1,2}/\d{1,2}/\d{4}\s+Page\s+\d+\s+of\s+\d+",
        " ",
        body,
        flags=re.IGNORECASE,
    )
    body = re.sub(r"(?m)^\s*\d+\s*$", " ", body)
    tokens: list[tuple[str, float | int]] = []
    for match in TABLE_TOKEN_RE.finditer(body):
        if match.group("percent") is not None:
            tokens.append(("percent", int(match.group("percent")[:-1])))
        else:
            tokens.append(("number", float(match.group("number"))))

    rows: list[dict[str, float | int]] = []
    cursor = 0
    while cursor < len(tokens):
        numeric_values: list[float] = []
        while cursor < len(tokens) and tokens[cursor][0] == "number":
            numeric_values.append(float(tokens[cursor][1]))
            cursor += 1
        percentiles: list[int] = []
        while cursor < len(tokens) and tokens[cursor][0] == "percent":
            percentiles.append(int(tokens[cursor][1]))
            cursor += 1
        if not numeric_values or not percentiles:
            raise ValueError("Unexpected table token ordering")
        if len(numeric_values) != 2 * len(percentiles):
            raise ValueError(
                f"Found {len(percentiles)} percentiles with "
                f"{len(numeric_values)} numeric bounds"
            )

        count = len(percentiles)
        lows = numeric_values[:count]
        highs = numeric_values[count:]
        rows.extend(
            {"lowerBound": low, "upperBound": high, "percentile": percentile}
            for low, high, percentile in zip(lows, highs, percentiles, strict=True)
        )

    validate_rows(rows)
    return rows


def validate_rows(rows: list[dict[str, float | int]]) -> None:
    if len(rows) != 102:
        raise ValueError(f"Expected 102 mapping rows; found {len(rows)}")

    expected = list(range(100)) + [100, 100]
    observed = [int(row["percentile"]) for row in rows]
    if observed != expected:
        raise ValueError("Percentiles must be 0 through 99 followed by two 100 rows")

    for index, row in enumerate(rows):
        low = float(row["lowerBound"])
        high = float(row["upperBound"])
        if not low < high:
            raise ValueError(f"Row {index} has a non-increasing interval")
        if index and abs(low - float(rows[index - 1]["upperBound"])) > 1e-9:
            raise ValueError(f"Row {index} is not contiguous with the previous row")


def _extract_float(text: str, label: str) -> float:
    pattern = rf"{re.escape(label)}[^:]*:\s*([0-9.]+)"
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        raise ValueError(f"Missing metadata: {label}")
    return float(match.group(1))


def parse_table(text: str, release: ReleaseMetadata) -> dict[str, object]:
    rows = parse_rows(text)
    return {
        "referenceYear": release.reference_year,
        "releaseLabel": release.release_label,
        "releaseYear": release.release_year,
        "timelinePosition": release.timeline_position,
        "databaseAsOf": release.database_as_of,
        "formulaVersion": release.formula_version,
        "scalingFactor": _extract_float(text, "scaling factor"),
        "diabetesPrevalence": _extract_float(text, "Diabetes percentage") / 100,
        "hypertensionPrevalence": _extract_float(text, "Hypertension percentage") / 100,
        "sourceURL": release.source_url,
        "upperBounds": [float(row["upperBound"]) for row in rows],
    }


def validate_catalog(tables: Iterable[dict[str, object]]) -> list[dict[str, object]]:
    catalog = list(tables)
    if not catalog:
        raise ValueError("Mapping catalog is empty")
    positions = [float(table["timelinePosition"]) for table in catalog]
    if positions != sorted(positions) or len(positions) != len(set(positions)):
        raise ValueError("Timeline positions must be unique and increasing")
    for table in catalog:
        bounds = [float(value) for value in table["upperBounds"]]
        if len(bounds) != 102 or any(a >= b for a, b in zip(bounds, bounds[1:])):
            raise ValueError(f"Invalid bounds for {table['releaseLabel']}")
        if table["formulaVersion"] not in {"legacyRaceHCV", "raceHCVNeutral2024"}:
            raise ValueError(f"Unknown formula version for {table['releaseLabel']}")
    return catalog


def write_json(path: Path, tables: Iterable[dict[str, object]]) -> None:
    path.write_text(
        json.dumps({"schemaVersion": 1, "tables": validate_catalog(tables)}, indent=2)
        + "\n",
        encoding="utf-8",
    )
