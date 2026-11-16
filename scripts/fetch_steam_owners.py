"""Downloads estimated Steam owner ranges into data/raw/steam/owners.csv.

Usage: python scripts/fetch_steam_owners.py [--revision SHA]

Source: the Steam Games Dataset on Hugging Face (MIT license), a copy of SteamSpy data:
https://huggingface.co/datasets/FronkonGames/steam-games-dataset
The download is pinned to a dataset revision so reruns give the same rows. The script streams
games.csv (about 400 MB) and keeps only the app id, name and owner range.
"""
import argparse
import csv
import io
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "raw" / "steam"
DATASET = "FronkonGames/steam-games-dataset"
REVISION = "6c21457b9ebf0a6a7f5b91e11281d65d456ea30e"  # dataset version of 2026-11-08

# Columns kept, by position. The header row merges two column names ("DiscountDLC count"),
# so columns after Price do not line up with their names. These three come before it.
KEEP = {0: "AppID", 1: "Name", 3: "Estimated owners"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", default=REVISION, help="dataset commit to download")
    args = parser.parse_args()

    url = f"https://huggingface.co/datasets/{DATASET}/resolve/{args.revision}/games.csv"
    OUT.mkdir(parents=True, exist_ok=True)
    csv.field_size_limit(2**31 - 1)  # descriptions and screenshot lists are long

    rows = 0
    with urllib.request.urlopen(url, timeout=120) as r, \
            open(OUT / "owners.csv", "w", newline="", encoding="utf-8") as f:
        reader = csv.reader(io.TextIOWrapper(r, encoding="utf-8-sig", newline=""))
        header = next(reader)
        for i, name in KEEP.items():
            if header[i] != name:
                raise SystemExit(f"column {i} is {header[i]!r}, expected {name!r}")
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["app_id", "name", "owners"])
        for rec in reader:
            w.writerow([rec[0], rec[1], rec[3]])
            rows += 1

    source = {"dataset": f"https://huggingface.co/datasets/{DATASET}", "revision": args.revision,
              "file": "games.csv", "rows": rows,
              "downloaded_at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    (OUT / "source.json").write_text(json.dumps(source, indent=1), encoding="utf-8")
    print(f"owners.csv: {rows} apps from {DATASET}@{args.revision[:7]}")


if __name__ == "__main__":
    main()
