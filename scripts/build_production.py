"""Builds the production CSVs in data/production/ from the raw IGDB and Steam pulls.

Usage: python scripts/build_production.py

Run scripts/fetch_igdb.py and scripts/fetch_steam_owners.py first. Writes one CSV per table in
sql/schema.sql and prints a count for every row that was dropped or changed while cleaning.
The counts are also saved to data/production/build_counts.json.
"""
import csv
import json
import re
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IGDB = ROOT / "data" / "raw" / "igdb"
OWNERS = ROOT / "data" / "raw" / "steam" / "owners.csv"
OUT = ROOT / "data" / "production"
NULL = r"\N"  # what LOAD DATA reads as NULL
STEAM = 1  # IGDB external_game_source id for Steam
INT_MAX = 2**31 - 1
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)

counts = Counter()


def text(value, limit, what):
    """Trims whitespace, joins lines and cuts to the column length, counting each change."""
    cleaned = re.sub(r"\s+", " ", value).strip()
    if cleaned != value:
        counts[f"{what}: whitespace cleaned"] += 1
    if len(cleaned) > limit:
        counts[f"{what}: cut to {limit} characters"] += 1
        cleaned = cleaned[:limit].rstrip()
    return cleaned


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def load_games():
    games = []
    for page in sorted(IGDB.glob("games-*.json")):
        games += json.loads(page.read_text(encoding="utf-8"))
    return sorted(games, key=lambda g: g["id"])


def load_owners():
    """Returns {app id: (name, low, high)} from the Steam Games Dataset extract."""
    owners = {}
    with open(OWNERS, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            low, high = (int(x) for x in row["owners"].split(" - "))
            owners[int(row["app_id"])] = (row["name"], low, high)
    return owners


def steam_id(game, owners):
    """Picks the game's Steam app id: one listed in the owners data first, then the lowest."""
    ids = set()
    for ext in game.get("external_games", []):
        if ext.get("external_game_source") != STEAM:
            continue
        uid = ext.get("uid", "")
        if uid.isdigit() and int(uid) <= INT_MAX:
            ids.add(int(uid))
        else:
            counts["steam id: not a valid app id, ignored"] += 1
    if len(ids) > 1:
        counts["game: several Steam app ids, kept one"] += 1
    return min(ids, key=lambda i: (i not in owners, i)) if ids else None


def write(name, header, rows):
    """Writes a CSV for LOAD DATA, which treats backslash as an escape character."""
    with open(OUT / f"{name}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        for row in rows:
            w.writerow([v.replace("\\", "\\\\") if isinstance(v, str) and v != NULL else v for v in row])
    counts[f"rows written: {name}"] = len(rows)


def main():
    games = load_games()
    owners = load_owners()
    OUT.mkdir(parents=True, exist_ok=True)
    counts["input: IGDB games"] = len(games)
    counts["input: Steam Games Dataset apps"] = len(owners)

    # Steam app ids, keeping each id on the lowest IGDB game id that lists it (steam_app_id is UNIQUE).
    steam, holder = {}, {}
    for g in games:
        sid = steam_id(g, owners)
        if sid is None:
            continue
        if sid in holder:
            counts["steam id: already used by another game, set to NULL"] += 1
            continue
        holder[sid] = g["id"]
        steam[g["id"]] = sid

    game_rows, gp_rows, gg_rows, gc_rows = [], [], [], []
    platforms, genres, companies = {}, {}, {}
    for g in games:
        title = text(g["name"], 255, "game title")
        sid = steam.get(g["id"])
        low = high = NULL
        if sid is not None:
            if sid in owners:
                name, low, high = owners[sid]
                if norm(name) != norm(title):
                    counts["steam id: Steam name differs from IGDB title (kept)"] += 1
                if low == high == 0:  # "0 - 0" means the dataset has no estimate, not zero owners
                    counts["steam id: owner range 0 - 0, owners NULL"] += 1
                    low = high = NULL
            else:
                counts["steam id: not in Steam Games Dataset, owners NULL"] += 1
        game_rows.append([g["id"], title, NULL if sid is None else sid, low, high])

        # Earliest release date per platform. Platforms without a dated release keep NULL.
        dates = {p["id"]: None for p in g.get("platforms", [])}
        for p in g.get("platforms", []):
            platforms[p["id"]] = p["name"]
        for rd in g.get("release_dates", []):
            if "platform" not in rd:
                counts["release date: no platform, dropped"] += 1
                continue
            pid = rd["platform"]["id"]
            platforms[pid] = rd["platform"]["name"]
            if pid not in dates:
                counts["release date: platform missing from game's platform list, added"] += 1
                dates[pid] = None
            if "date" not in rd:
                continue
            d = (EPOCH + timedelta(seconds=rd["date"])).date()
            if dates[pid] is None or d < dates[pid]:
                dates[pid] = d
        if all(d is None for d in dates.values()):
            counts["game: no dated release on any platform"] += 1
        for pid, d in sorted(dates.items()):
            gp_rows.append([g["id"], pid, d.isoformat() if d else NULL])

        if not g.get("genres"):
            counts["game: no genre"] += 1
        for ge in g.get("genres", []):
            genres[ge["id"]] = ge["name"]
            gg_rows.append([g["id"], ge["id"]])

        roles = {}
        for ic in g.get("involved_companies", []):
            c = ic["company"]
            companies[c["id"]] = c["name"]
            dev, pub = roles.get(c["id"], (False, False))
            roles[c["id"]] = (dev or ic.get("developer", False), pub or ic.get("publisher", False))
        kept = {cid: r for cid, r in roles.items() if r[0] or r[1]}
        counts["game_company: credit with neither developer nor publisher role, dropped"] += len(roles) - len(kept)
        if not any(dev for dev, _ in kept.values()):
            counts["game: no developer"] += 1
        if not any(pub for _, pub in kept.values()):
            counts["game: no publisher"] += 1
        for cid, (dev, pub) in sorted(kept.items()):
            gc_rows.append([g["id"], cid, int(dev), int(pub)])

    for table, names in (("platform", platforms), ("genre", genres)):
        dupes = sum(n - 1 for n in Counter(names.values()).values() if n > 1)
        if dupes:
            counts[f"{table}: duplicate name (UNIQUE would fail)"] = dupes

    write("game", ["game_id", "title", "steam_app_id", "steam_owners_low", "steam_owners_high"], game_rows)
    write("platform", ["platform_id", "name"],
          [[i, text(n, 100, "platform name")] for i, n in sorted(platforms.items())])
    write("genre", ["genre_id", "name"], [[i, text(n, 100, "genre name")] for i, n in sorted(genres.items())])
    write("company", ["company_id", "name"],
          [[i, text(n, 255, "company name")] for i, n in sorted(companies.items())])
    write("game_platform", ["game_id", "platform_id", "release_date"], gp_rows)
    write("game_genre", ["game_id", "genre_id"], gg_rows)
    write("game_company", ["game_id", "company_id", "is_developer", "is_publisher"], gc_rows)

    for key, value in sorted(counts.items()):
        print(f"{value:>9}  {key}")
    (OUT / "build_counts.json").write_text(json.dumps(dict(sorted(counts.items())), indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
