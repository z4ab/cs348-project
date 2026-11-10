"""Downloads main games from the IGDB API into data/raw/igdb/, one JSON file per page.

Usage: python scripts/fetch_igdb.py [--max-games N]

Needs TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET in .env (see .env.example) or the environment.
Fetches every main game (game_type 0) that has at least one release date, including future
releases, with its platforms, genres, per-platform release dates, companies and external store ids.
Pages are fetched in game id order. A rerun resumes after the last saved page.
"""
import argparse
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "raw" / "igdb"
API = "https://api.igdb.com/v4/games"
PAGE = 500  # IGDB's maximum page size
DELAY = 0.3  # IGDB allows 4 requests per second

FIELDS = ",".join([
    "name", "game_type",
    "platforms.name",
    "genres.name",
    "release_dates.date", "release_dates.platform.name",
    "involved_companies.company.name", "involved_companies.developer", "involved_companies.publisher",
    "external_games.uid", "external_games.external_game_source",
])
WHERE = "game_type = 0 & release_dates != null"


def credentials():
    env = {}
    path = ROOT / ".env"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip()
    env.update({k: v for k, v in os.environ.items() if k.startswith("TWITCH_")})
    try:
        return env["TWITCH_CLIENT_ID"], env["TWITCH_CLIENT_SECRET"]
    except KeyError:
        raise SystemExit("Set TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET in .env")


def token(client_id, secret):
    query = urllib.parse.urlencode({"client_id": client_id, "client_secret": secret,
                                    "grant_type": "client_credentials"})
    req = urllib.request.Request("https://id.twitch.tv/oauth2/token?" + query, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["access_token"]


def post(body, headers):
    for attempt in range(5):
        req = urllib.request.Request(API, data=body.encode(), headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500:
                raise
        except urllib.error.URLError:
            pass
        time.sleep(2 ** attempt)
    raise SystemExit("IGDB request failed 5 times")


def resume_point():
    """Returns (next page number, last game id saved)."""
    pages = sorted(OUT.glob("games-*.json"))
    if not pages:
        return 0, 0
    last = json.loads(pages[-1].read_text(encoding="utf-8"))
    return len(pages), last[-1]["id"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-games", type=int, help="stop after about this many games (for testing)")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    client_id, secret = credentials()
    headers = {"Client-ID": client_id, "Authorization": f"Bearer {token(client_id, secret)}"}

    page, last_id = resume_point()
    fetched = page * PAGE
    while args.max_games is None or fetched < args.max_games:
        body = f"fields {FIELDS}; where {WHERE} & id > {last_id}; sort id asc; limit {PAGE};"
        games = post(body, headers)
        if not games:
            break
        (OUT / f"games-{page:04d}.json").write_text(json.dumps(games), encoding="utf-8")
        page, last_id, fetched = page + 1, games[-1]["id"], fetched + len(games)
        print(f"page {page}: {fetched} games, last id {last_id}", flush=True)
        time.sleep(DELAY)
    print(f"done: {fetched} games in {page} pages in {OUT}")


if __name__ == "__main__":
    main()
