# CS 348 Fall 2026 Course Project: Video Game Tracker

MySQL + FastAPI (raw SQL via `pymysql`) + React (Vite).

## Project structure

- `docker-compose.yml`: MySQL 8 with the `cs348` database and `cs348_app` user
- `sql/`: database scripts
  - `setup_db.sql`: creates the database and user on a MySQL install without Docker
  - `schema.sql`: creates the tables, constraints, and indexes
  - `load_sample.sql`: loads `data/sample/*.csv`
  - `load_production.sql`: loads `data/production/*.csv`
  - `test-sample.sql`, `test-sample.out`: feature queries and output on the sample database
  - `test-production.sql`, `test-production.out`: feature queries and output on the production database
- `data/sample/`: small sample dataset, one CSV per table
- `data/production/`: production dataset, one CSV per table (generated, not committed)
- `data/raw/steamspy.json`: cached SteamSpy responses
- `data/raw/igdb/`, `data/raw/steam/`: raw production pulls (generated, not committed)
- `games.json`: saved IGDB pull of 20 games
- `scripts/build_sample.py`: builds the sample dataset
- `scripts/fetch_igdb.py`: downloads every main IGDB game with a release date into `data/raw/igdb/`
- `scripts/fetch_steam_owners.py`: downloads Steam owner ranges into `data/raw/steam/`
- `scripts/build_production.py`: builds the production dataset from the raw pulls
- `backend/`: FastAPI application
- `frontend/`: React application

## Create and load the sample database

Docker is required. Run the commands from the repository root.

Start MySQL:

```bash
docker compose up -d
```

### Windows PowerShell

Create or reset the tables:

```powershell
Get-Content sql/schema.sql | docker compose exec -T mysql mysql -u cs348_app -pcs348_pass cs348
```

Load the sample data:

```powershell
Get-Content sql/load_sample.sql | docker compose exec -T mysql mysql --local-infile=1 -u cs348_app -pcs348_pass cs348
```

### macOS/Linux

```bash
docker compose exec -T mysql mysql -u cs348_app -pcs348_pass cs348 < sql/schema.sql
docker compose exec -T mysql mysql --local-infile=1 -u cs348_app -pcs348_pass cs348 < sql/load_sample.sql
```

To rebuild the sample CSV files:

```bash
python scripts/build_sample.py
```

## Create and load the production database

Game, platform, genre and company data is real. It comes from two sources:

- [IGDB API](https://api-docs.igdb.com/): every main game (`game_type = 0`) with at least one release date, including future releases.
- [Steam Games Dataset](https://huggingface.co/datasets/FronkonGames/steam-games-dataset) on Hugging Face (MIT license), a copy of SteamSpy data, pinned to revision `6c21457`. It gives each Steam game's estimated owner range.

Users, platform ownership, library entries and reviews are synthetic, generated with a fixed seed. Row counts from the current build:

| Table | Rows |
|---|---|
| game | 268,184 |
| game_platform | 436,227 |
| game_genre | 505,080 |
| game_company | 218,667 |
| company | 61,645 |
| platform | 215 |
| genre | 23 |
| app_user | 25,000 |
| user_platform | 77,107 |
| library_entry | 126,682 |
| review | 59,102 |

The CSVs are too large to commit, so build them locally. The IGDB fetch needs a Twitch client id and secret ([IGDB getting started](https://api-docs.igdb.com/#getting-started)). Copy `.env.example` to `.env` and fill in `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET`. Then run:

```bash
python scripts/fetch_igdb.py          # about 270,000 games, a few minutes. A rerun resumes.
python scripts/fetch_steam_owners.py  # streams about 400 MB, keeps about 5 MB
python scripts/build_production.py    # writes data/production/*.csv
```

`build_production.py` prints how many rows were dropped or changed while cleaning, and saves the counts to `data/production/build_counts.json`.

### Windows PowerShell

Reset the database:

```powershell
Get-Content sql/schema.sql | docker compose exec -T mysql mysql -u cs348_app -pcs348_pass cs348
```

Load the production data:

```powershell
Get-Content sql/load_production.sql | docker compose exec -T mysql mysql --local-infile=1 -u cs348_app -pcs348_pass cs348
```

### macOS/Linux

```bash
docker compose exec -T mysql mysql -u cs348_app -pcs348_pass cs348 < sql/schema.sql
docker compose exec -T mysql mysql --local-infile=1 -u cs348_app -pcs348_pass cs348 < sql/load_production.sql
```

## Run the feature queries

### Sample database

```bash
docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348 < sql/test-sample.sql > sql/test-sample.out
```

On Windows PowerShell:

```powershell
Get-Content sql/test-sample.sql | docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348 | Out-File -Encoding utf8 sql/test-sample.out
```

### Production database

```bash
docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348 < sql/test-production.sql > sql/test-production.out
```

On Windows PowerShell:

```powershell
Get-Content sql/test-production.sql | docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348 | Out-File -Encoding utf8 sql/test-production.out
```

The production tests cover:

1. Searching games by title, platform, and genre
2. Finding upcoming releases on a user's platforms that are not already in their library
3. Adding and updating personal library entries
4. Ranking games in a genre using average review scores

Transactions with `ROLLBACK` are used for the update and insert tests so that the production database is not permanently modified.

## Production query performance

Feature 4 averages review scores per game, so `sql/schema.sql` adds a covering index:

```sql
CREATE INDEX idx_review_game_score ON review(game_id, score);
```

On the production database, `EXPLAIN` shows the review lookup changing from `ref` on a `game_id` index with `Using where` to `ref` on `idx_review_game_score` with `Using index`. That means scores are read from the index without touching the table rows. The Shooter query in `sql/test-production.sql` (36,968 Shooter games) went from about 113 ms to about 100 ms with `EXPLAIN ANALYZE`, the median of 5 runs in local Docker. Most of the time goes to scanning the genre's `game_genre` rows, not the review lookup.

## Run the app

Backend, in one terminal:

```bash
cd backend
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
.venv/Scripts/uvicorn main:app --reload
```

Frontend, in a second terminal:

```bash
cd frontend
npm install
npm run dev
```

Open:

`http://localhost:5173`

On macOS/Linux, use `.venv/bin/` instead of `.venv/Scripts/`.

## Features

| Feature | In the app | Sample SQL test | Production SQL test |
|---|---|---|---|
| 1. Search games by title, platform, and genre | Yes | Yes | Yes |
| 2. Upcoming releases on my platforms, excluding games already in my library | No | Yes | Yes |
| 3. View a library, add a game, and update status/hours | Yes | Yes | Yes |
| 4. Top-rated games in a genre by average review score | No | Yes | Yes |

Features 1 and 3 are currently implemented in `backend/main.py` and `frontend/src/App.jsx`.