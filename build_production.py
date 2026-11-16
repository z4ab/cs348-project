"""Builds the production CSVs in data/production/.

Game data comes from games.json and SteamSpy.
Users, libraries, and reviews are generated synthetically.

Usage:
    python scripts/build_production.py
"""

import csv
import difflib
import json
import random
import re
import time
import urllib.request

from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "production"
CACHE = ROOT / "data" / "raw" / "steamspy.json"

NULL = r"\N"

MAX_STEAM_APP_ID = 5_000_000

# Production database size
NUM_USERS = 5000


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def steamspy(appid, cache):
    key = str(appid)

    if key not in cache:
        url = f"https://steamspy.com/api.php?request=appdetails&appid={appid}"

        with urllib.request.urlopen(url, timeout=30) as r:
            cache[key] = json.load(r)

        time.sleep(1)

    return cache[key]


def find_steam(game, cache):
    best = None

    for ext in game.get("external_games", []):
        uid = ext.get("uid", "")

        if not uid.isdigit():
            continue

        if int(uid) > MAX_STEAM_APP_ID:
            continue

        row = steamspy(int(uid), cache)

        name = row.get("name") or ""

        if not name:
            continue

        ratio = difflib.SequenceMatcher(
            None,
            norm(name),
            norm(game["name"])
        ).ratio()

        if ratio >= 0.8 and (best is None or ratio > best[0]):
            best = (
                ratio,
                int(uid),
                row
            )

    if best:
        return best[1], best[2]

    return None, None


def owners_range(row):
    low, high = (
        int(x.replace(",", ""))
        for x in row["owners"].split("..")
    )

    return low, high


def write(name, header, rows):
    OUT.mkdir(parents=True, exist_ok=True)

    with open(
        OUT / f"{name}.csv",
        "w",
        newline="",
        encoding="utf-8"
    ) as f:

        w = csv.writer(
            f,
            lineterminator="\n"
        )

        w.writerow(header)
        w.writerows(rows)

    print(f"{name}.csv: {len(rows)} rows")


def main():
    src = ROOT / "games.json"

    data = json.loads(
        src.read_text(
            encoding="utf-8-sig"
        )
    )

    if isinstance(data, dict):
        games = data["value"]
    else:
        games = data

    if CACHE.exists():
        cache = json.loads(
            CACHE.read_text(
                encoding="utf-8"
            )
        )
    else:
        cache = {}

    OUT.mkdir(
        parents=True,
        exist_ok=True
    )

    CACHE.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    game_rows = []

    platforms = {}
    genres = {}
    companies = {}

    gp_rows = []
    gg_rows = []
    gc_rows = []

    try:
        for g in sorted(
            games,
            key=lambda g: g["id"]
        ):

            appid, row = find_steam(
                g,
                cache
            )

            if row:
                low, high = owners_range(row)
            else:
                low = None
                high = None

            game_rows.append([
                g["id"],
                g["name"],
                appid or NULL,
                NULL if low is None else low,
                NULL if high is None else high
            ])

            # Platforms and release dates
            dates = {}

            for p in g.get(
                "platforms",
                []
            ):
                pid = p["id"]

                platforms[pid] = p["name"]

                dates[pid] = None

            for rd in g.get(
                "release_dates",
                []
            ):
                if "date" not in rd:
                    continue

                if "platform" not in rd:
                    continue

                pid = rd["platform"]["id"]

                platforms[pid] = (
                    rd["platform"]["name"]
                )

                d = datetime.fromtimestamp(
                    rd["date"],
                    timezone.utc
                ).date()

                if (
                    dates.get(pid) is None
                    or d < dates[pid]
                ):
                    dates[pid] = d

            for pid, d in sorted(
                dates.items()
            ):
                gp_rows.append([
                    g["id"],
                    pid,
                    d.isoformat() if d else NULL
                ])

            # Genres
            for ge in g.get(
                "genres",
                []
            ):
                genres[
                    ge["id"]
                ] = ge["name"]

                gg_rows.append([
                    g["id"],
                    ge["id"]
                ])

            # Developers and publishers
            roles = {}

            for ic in g.get(
                "involved_companies",
                []
            ):
                c = ic["company"]

                companies[
                    c["id"]
                ] = c["name"]

                dev, pub = roles.get(
                    c["id"],
                    (False, False)
                )

                roles[c["id"]] = (
                    dev
                    or ic.get(
                        "developer",
                        False
                    ),

                    pub
                    or ic.get(
                        "publisher",
                        False
                    )
                )

            for cid, role in sorted(
                roles.items()
            ):
                dev, pub = role

                if dev or pub:
                    gc_rows.append([
                        g["id"],
                        cid,
                        int(dev),
                        int(pub)
                    ])

    finally:
        CACHE.write_text(
            json.dumps(
                cache,
                indent=1
            ),
            encoding="utf-8"
        )

    write(
        "game",
        [
            "game_id",
            "title",
            "steam_app_id",
            "steam_owners_low",
            "steam_owners_high"
        ],
        game_rows
    )

    write(
        "platform",
        [
            "platform_id",
            "name"
        ],
        sorted(
            platforms.items()
        )
    )

    write(
        "genre",
        [
            "genre_id",
            "name"
        ],
        sorted(
            genres.items()
        )
    )

    write(
        "company",
        [
            "company_id",
            "name"
        ],
        sorted(
            companies.items()
        )
    )

    write(
        "game_platform",
        [
            "game_id",
            "platform_id",
            "release_date"
        ],
        gp_rows
    )

    write(
        "game_genre",
        [
            "game_id",
            "genre_id"
        ],
        gg_rows
    )

    write(
        "game_company",
        [
            "game_id",
            "company_id",
            "is_developer",
            "is_publisher"
        ],
        gc_rows
    )

    build_users(
        game_rows,
        gp_rows
    )


def build_users(
    game_rows,
    gp_rows
):
    rng = random.Random(348)

    base = datetime(
        2026,
        9,
        1,
        12,
        0
    )

    # ---------------------------------
    # Create 5,000 users
    # ---------------------------------

    users = [
        [1, "pixelpanda"]
    ]

    for uid in range(
        2,
        NUM_USERS + 1
    ):
        users.append([
            uid,
            f"user_{uid:05d}"
        ])

    # ---------------------------------
    # User platforms
    # ---------------------------------

    all_pids = sorted({
        pid
        for _, pid, _
        in gp_rows
    })

    up_rows = []

    for uid, _ in users:

        if not all_pids:
            break

        # Pixelpanda must own Nintendo Switch.
        # Nintendo Switch has IGDB platform id 130.
        # This makes Feature 2 return Soma.
        if uid == 1 and 130 in all_pids:

            owned = {130}

            remaining = [
                pid
                for pid in all_pids
                if pid != 130
            ]

            extra_count = min(
                2,
                len(remaining)
            )

            if extra_count > 0:
                owned.update(
                    rng.sample(
                        remaining,
                        extra_count
                    )
                )

        else:

            count = rng.randint(
                1,
                min(
                    3,
                    len(all_pids)
                )
            )

            owned = set(
                rng.sample(
                    all_pids,
                    count
                )
            )

        for pid in sorted(owned):
            up_rows.append([
                uid,
                pid
            ])

    # ---------------------------------
    # Library entries and reviews
    # ---------------------------------

    game_ids = [
        row[0]
        for row in game_rows
    ]

    title_to_id = {
        row[1]: row[0]
        for row in game_rows
    }

    lib_rows = []
    rev_rows = []

    comments = [
        "Loved it.",
        "Great game.",
        "Fun but difficult.",
        "Great atmosphere.",
        "Would play again.",
        "Not for me.",
        "Excellent gameplay.",
        "Interesting story."
    ]

    for uid, _ in users:

        if not game_ids:
            break

        max_games = min(
            15,
            len(game_ids)
        )

        min_games = min(
            5,
            max_games
        )

        amount = rng.randint(
            min_games,
            max_games
        )

        available_games = list(
            game_ids
        )

        # Keep Soma OUT of pixelpanda's library.
        # Feature 2 excludes games already in the library.
        # Feature 3b also inserts Soma into the library.
        if (
            uid == 1
            and "Soma" in title_to_id
        ):
            soma_id = (
                title_to_id["Soma"]
            )

            if soma_id in available_games:
                available_games.remove(
                    soma_id
                )

        amount = min(
            amount,
            len(available_games)
        )

        picked = set(
            rng.sample(
                available_games,
                amount
            )
        )

        # Make sure pixelpanda already owns
        # Darksiders because Feature 3a
        # updates that library entry.
        if (
            uid == 1
            and "Darksiders"
            in title_to_id
        ):
            picked.add(
                title_to_id[
                    "Darksiders"
                ]
            )

        for gid in sorted(picked):

            status = rng.choice([
                "backlog",
                "playing",
                "completed"
            ])

            if status == "backlog":
                hours = 0.0

            elif status == "playing":
                hours = round(
                    rng.uniform(
                        1,
                        70
                    ),
                    1
                )

            else:
                hours = round(
                    rng.uniform(
                        5,
                        150
                    ),
                    1
                )

            added = (
                base
                + timedelta(
                    days=rng.randint(
                        0,
                        300
                    ),
                    hours=rng.randint(
                        0,
                        23
                    )
                )
            )

            lib_rows.append([
                uid,
                gid,
                status,
                hours,
                added.strftime(
                    "%Y-%m-%d %H:%M:%S"
                )
            ])

            # Generate reviews for many
            # non-backlog games.
            if (
                status != "backlog"
                and rng.random() < 0.7
            ):

                score = rng.randint(
                    1,
                    10
                )

                body = rng.choice(
                    comments
                )

                created = (
                    added
                    + timedelta(
                        days=rng.randint(
                            1,
                            30
                        )
                    )
                )

                rev_rows.append([
                    uid,
                    gid,
                    score,
                    body,
                    created.strftime(
                        "%Y-%m-%d %H:%M:%S"
                    )
                ])

    write(
        "app_user",
        [
            "user_id",
            "username"
        ],
        users
    )

    write(
        "user_platform",
        [
            "user_id",
            "platform_id"
        ],
        up_rows
    )

    write(
        "library_entry",
        [
            "user_id",
            "game_id",
            "status",
            "hours_played",
            "added_at"
        ],
        lib_rows
    )

    write(
        "review",
        [
            "user_id",
            "game_id",
            "score",
            "body",
            "created_at"
        ],
        rev_rows
    )


if __name__ == "__main__":
    main()