#!/usr/bin/env python3
"""Check HRSA's current KDPI PDF and stage a validated annual update."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path

from generate_kdpi_mapping_data import render_swift
from kdpi_mapping_tools import ReleaseMetadata, parse_table, validate_catalog, write_json


CURRENT_SOURCE_URL = "https://www.hrsa.gov/sites/default/files/hrsa/optn/kdpi_mapping_table.pdf"


def download_reader_text(official_url: str) -> str:
    reader_url = "https://r.jina.ai/http://" + official_url.removeprefix("https://")
    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as temporary:
        output = Path(temporary.name)
    subprocess.run(
        [
            "curl", "--fail", "--location", "--silent", "--show-error",
            "--max-time", "90", "--output", str(output), reader_url,
        ],
        check=True,
    )
    text = output.read_text(encoding="utf-8")
    if "KDRI to KDPI Mapping Table" not in text or official_url not in text:
        raise ValueError("Reader response did not identify the requested official HRSA PDF")
    return text


def release_metadata(text: str, source_url: str) -> ReleaseMetadata:
    year_match = re.search(r"Reference population:.*?in\s+(20\d{2})\s+in the", text, re.IGNORECASE | re.DOTALL)
    date_match = re.search(
        r"database as of\s+([A-Za-z]+\s+\d{1,2},\s+20\d{2})",
        text,
        re.IGNORECASE,
    )
    if not year_match or not date_match:
        raise ValueError("Could not extract reference year and database date")
    reference_year = int(year_match.group(1))
    database_date = datetime.strptime(date_match.group(1), "%B %d, %Y").date().isoformat()
    release_year = reference_year + 1
    return ReleaseMetadata(
        reference_year=reference_year,
        release_label=f"{release_year} annual",
        release_year=release_year,
        timeline_position=release_year + 0.4,
        database_as_of=database_date,
        formula_version="raceHCVNeutral2024",
        source_url=source_url,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--swift-output", type=Path, required=True)
    parser.add_argument("--url", default=CURRENT_SOURCE_URL)
    parser.add_argument("--input", type=Path)
    args = parser.parse_args()

    text = args.input.read_text(encoding="utf-8") if args.input else download_reader_text(args.url)
    candidate = parse_table(text, release_metadata(text, args.url))

    raw = json.loads(args.catalog.read_text(encoding="utf-8"))
    if raw.get("schemaVersion") != 1:
        raise ValueError("Unsupported catalog schema")
    tables = validate_catalog(raw["tables"])
    latest = tables[-1]

    if candidate["referenceYear"] < latest["referenceYear"]:
        raise ValueError("The official current PDF regressed to an older reference year")
    if candidate["referenceYear"] == latest["referenceYear"]:
        compared = ("upperBounds", "scalingFactor", "diabetesPrevalence", "hypertensionPrevalence")
        if any(candidate[key] != latest[key] for key in compared):
            raise ValueError("Current-year official KDPI data changed; manual review required")
        print(f"No update: reference year {candidate['referenceYear']} is already pinned")
        return
    if candidate["referenceYear"] != latest["referenceYear"] + 1:
        raise ValueError("The new reference year is not the expected annual successor")

    tables.append(candidate)
    write_json(args.catalog, tables)
    args.swift_output.write_text(render_swift(args.catalog), encoding="utf-8")
    print(f"Staged validated KDPI reference year {candidate['referenceYear']}")


if __name__ == "__main__":
    main()
