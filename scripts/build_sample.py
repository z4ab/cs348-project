"""Builds the sample CSVs in data/sample/ from an IGDB pull (games.json) and SteamSpy.

Usage: python scripts/build_sample.py [path/to/games.json]

SteamSpy responses are cached in data/raw/steamspy.json, so reruns need no network.
User, library and review rows are synthetic, generated with a fixed seed.
"""
import csv
import difflib
import json
import random
import re
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "sample"
CACHE = ROOT / "data" / "raw" / "steamspy.json"
NULL = r"\N"  # what LOAD DATA reads as NULL

# Steam app ids are well below this; larger external uids belong to other stores (GOG, etc.).
MAX_STEAM_APP_ID = 5_000_000


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def steamspy(appid, cache):
    key = str(appid)
    if key not in cache:
        url = f"https://steamspy.com/api.php?request=appdetails&appid={appid}"
        with urllib.request.urlopen(url, timeout=30) as r:
            cache[key] = json.load(r)
        time.sleep(1)  # SteamSpy allows 1 appdetails request per second
    return cache[key]


def find_steam(game, cache):
    """Returns (appid, steamspy row) for the external uid whose SteamSpy name matches the game."""
    best = None
    for ext in game.get("external_games", []):
        uid = ext.get("uid", "")
        if not uid.isdigit() or int(uid) > MAX_STEAM_APP_ID:
            continue
        row = steamspy(int(uid), cache)
        name = row.get("name") or ""
        if not name:
            continue
        ratio = difflib.SequenceMatcher(None, norm(name), norm(game["name"])).ratio()
        if ratio >= 0.8 and (best is None or ratio > best[0]):
            best = (ratio, int(uid), row)
    return (best[1], best[2]) if best else (None, None)


def owners_range(row):
    low, high = (int(x.replace(",", "")) for x in row["owners"].split(".."))
    return low, high


def write(name, header, rows):
    with open(OUT / f"{name}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}.csv: {len(rows)} rows")


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "games.json"
    data = json.loads(src.read_text(encoding="utf-8-sig"))
    games = data["value"] if isinstance(data, dict) else data

    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.parent.mkdir(parents=True, exist_ok=True)

    game_rows, platforms, genres, companies = [], {}, {}, {}
    gp_rows, gg_rows, gc_rows = [], [], []
    try:
        for g in sorted(games, key=lambda g: g["id"]):
            appid, row = find_steam(g, cache)
            low, high = owners_range(row) if row else (None, None)
            game_rows.append([g["id"], g["name"],
                              appid or NULL, NULL if low is None else low, NULL if high is None else high])

            # Earliest release date per platform; platforms with no date keep NULL.
            dates = {p["id"]: None for p in g.get("platforms", [])}
            for p in g.get("platforms", []):
                platforms[p["id"]] = p["name"]
            for rd in g.get("release_dates", []):
                if "date" not in rd or "platform" not in rd:
                    continue
                pid = rd["platform"]["id"]
                platforms[pid] = rd["platform"]["name"]
                d = datetime.fromtimestamp(rd["date"], timezone.utc).date()
                if dates.get(pid) is None or d < dates[pid]:
                    dates[pid] = d
            for pid, d in sorted(dates.items()):
                gp_rows.append([g["id"], pid, d.isoformat() if d else NULL])

            for ge in g.get("genres", []):
                genres[ge["id"]] = ge["name"]
                gg_rows.append([g["id"], ge["id"]])

            roles = {}
            for ic in g.get("involved_companies", []):
                c = ic["company"]
                companies[c["id"]] = c["name"]
                dev, pub = roles.get(c["id"], (False, False))
                roles[c["id"]] = (dev or ic.get("developer", False), pub or ic.get("publisher", False))
            for cid, (dev, pub) in sorted(roles.items()):
                if dev or pub:  # skip porting/supporting-only credits
                    gc_rows.append([g["id"], cid, int(dev), int(pub)])
    finally:
        CACHE.write_text(json.dumps(cache, indent=1), encoding="utf-8")

    write("game", ["game_id", "title", "steam_app_id", "steam_owners_low", "steam_owners_high"], game_rows)
    write("platform", ["platform_id", "name"], sorted(platforms.items()))
    write("genre", ["genre_id", "name"], sorted(genres.items()))
    write("company", ["company_id", "name"], sorted(companies.items()))
    write("game_platform", ["game_id", "platform_id", "release_date"], gp_rows)
    write("game_genre", ["game_id", "genre_id"], gg_rows)
    write("game_company", ["game_id", "company_id", "is_developer", "is_publisher"], gc_rows)

    build_users(game_rows, gp_rows)


def build_users(game_rows, gp_rows):
    rng = random.Random(348)
    base = datetime(2026, 9, 1, 12, 0)
    names = ["pixelpanda", "speedrunsam", "backlogbeth", "couchcoop", "retro_rita",
             "noscope_ned", "cozygamer", "lorehunter"]
    users = [[i + 1, n, (base + timedelta(days=i)).strftime("%Y-%m-%d %H:%M:%S")] for i, n in enumerate(names)]

    # Owned platforms: sample from the platforms the sample games are on.
    game_platforms = {}
    for gid, pid, _ in gp_rows:
        game_platforms.setdefault(gid, []).append(pid)
    all_pids = sorted({pid for _, pid, _ in gp_rows})
    pc = 6  # IGDB "PC (Microsoft Windows)"
    up_rows = []
    for uid, *_ in users:
        owned = {pc} if uid != 5 else set()  # retro_rita is console-only
        owned |= set(rng.sample(all_pids, 2))
        up_rows += [[uid, pid] for pid in sorted(owned)]

    # Library: weight game choice by Steam owners so popular games show up more often.
    weights = [(r[4] if r[4] != NULL else 20_000) ** 0.5 for r in game_rows]
    lib_rows, rev_rows = [], []
    comments = ["Loved it.", "Too short, but worth it.", "Controls feel dated now.",
                "Great atmosphere, weak ending.", "Could not stop playing.", "Gave up halfway."]
    for uid, *_ in users:
        if uid == 8:
            continue  # lorehunter has an empty library
        picked = set()
        while len(picked) < rng.randint(3, 6):
            picked.add(rng.choices(game_rows, weights)[0][0])
        for gid in sorted(picked):
            status = rng.choice(["backlog", "playing", "completed"])
            hours = 0.0 if status == "backlog" else round(rng.uniform(1, 60 if status == "playing" else 120), 1)
            added = base + timedelta(days=10 + rng.randint(0, 40), hours=rng.randint(0, 23))
            lib_rows.append([uid, gid, status, hours, added.strftime("%Y-%m-%d %H:%M:%S")])
            if status != "backlog" and rng.random() < 0.7:
                kind = rng.choice(["score", "body", "both"])
                score = rng.randint(3, 10) if kind != "body" else NULL
                body = rng.choice(comments) if kind != "score" else NULL
                created = added + timedelta(days=rng.randint(1, 10))
                rev_rows.append([uid, gid, score, body, created.strftime("%Y-%m-%d %H:%M:%S")])

    write("app_user", ["user_id", "username", "joined_at"], users)
    write("user_platform", ["user_id", "platform_id"], up_rows)
    write("library_entry", ["user_id", "game_id", "status", "hours_played", "added_at"], lib_rows)
    write("review", ["user_id", "game_id", "score", "body", "created_at"], rev_rows)


if __name__ == "__main__":
    main()
