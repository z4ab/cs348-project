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
  - `assumptions-production.sql`, `assumptions-production.out`: tests each schema assumption on the production database. `assumptions-production-before-filter.out` is the output before games without a genre, developer or publisher were dropped.
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

The build keeps only games with at least one genre, developer and publisher, as the schema assumptions require. That drops 150,524 of the 268,184 IGDB games.

Users, platform ownership, library entries and reviews are synthetic, generated with a fixed seed. Row counts from the current build:

| Table | Rows |
|---|---|
| game | 117,660 |
| game_platform | 234,882 |
| game_genre | 256,530 |
| game_company | 178,617 |
| company | 52,660 |
| platform | 203 |
| genre | 23 |
| app_user | 25,000 |
| user_platform | 77,107 |
| library_entry | 125,339 |
| review | 58,389 |

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

On the production database, MySQL reads the scores from the index alone, without touching the table rows. `EXPLAIN` shows `idx_review_game_score` with `Using index`. Without it, the plan is `ref` on a `game_id` index with `Using where`.

Measured with `EXPLAIN ANALYZE` on the Shooter query in `sql/test-production.sql` (13,297 Shooter games), in local Docker with a warm cache. Each figure is the median of 5 runs:

| Run | Without index | With index |
|---|---|---|
| 1 | 87.7 ms | 71.8 ms |
| 2 | 75.9 ms | 70.8 ms |

Times vary by about 20 ms between runs, so the gain is small. Right after a reload, with a cold cache, the indexed plan was slower.

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