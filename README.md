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
  - `perf-production.sql`, `perf-production.out`: query plans and timings for all five features, the index before/after comparisons and the too-many-indexes test on the production database (R-c, Task 8)
  - `assumptions-production.sql`, `assumptions-production.out`: tests each schema assumption on the production database. `assumptions-production-before-filter.out` is the output before games without a genre, developer or publisher were dropped.
- `data/sample/`: small sample dataset, one CSV per table
- `data/production/`: production dataset, one CSV per table (built by `scripts/build_production.py`)
- `data/raw/steamspy.json`: cached SteamSpy responses
- `data/raw/igdb/`, `data/raw/steam/`: raw production pulls (generated, not committed)
- `games.json`: saved IGDB pull of 20 games
- `scripts/build_sample.py`: builds the sample dataset
- `scripts/fetch_igdb.py`: downloads every main IGDB game with a release date into `data/raw/igdb/`
- `scripts/fetch_steam_owners.py`: downloads Steam owner ranges into `data/raw/steam/`
- `scripts/build_production.py`: builds the production dataset from the raw pulls
- `backend/`: FastAPI application
- `frontend/`: React application
- `docs/feature-tests.md`, `docs/screenshots/`: test steps and screenshots for Features 1-5 on the production database

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

The built CSVs are committed in `data/production/`, so loading them needs no API keys. Rebuilding them is optional, see [Rebuild the production CSVs](#rebuild-the-production-csvs-optional).

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

### Rebuild the production CSVs (optional)

Only needed to regenerate `data/production/`. The IGDB fetch needs a Twitch client id and secret ([IGDB getting started](https://api-docs.igdb.com/#getting-started)). Copy `.env.example` to `.env` and fill in `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET`. Then run:

```bash
python scripts/fetch_igdb.py          # about 270,000 games, a few minutes. A rerun resumes.
python scripts/fetch_steam_owners.py  # streams about 400 MB, keeps about 5 MB
python scripts/build_production.py    # writes data/production/*.csv
```

`build_production.py` prints how many rows were dropped or changed while cleaning, and saves the counts to `data/production/build_counts.json`.

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
5. Reading, writing and editing a game's reviews

Transactions with `ROLLBACK` are used for the update and insert tests so that the production database is not permanently modified.

## Production query performance

`sql/perf-production.sql` runs `EXPLAIN ANALYZE` and times all five features on the production database. It then compares Features 2 and 4 with and without their indexes and runs a too-many-indexes test. As in the spec appendix, each time is read back in the same `mysql` session from `performance_schema.events_statements_history`, and the reported figure is the median of five runs after one warm-up. The output is in `sql/perf-production.out`.

`sql/schema.sql` adds two indexes based on these measurements:

```sql
CREATE INDEX idx_gp_platform_date ON game_platform(platform_id, release_date);  -- Feature 2
CREATE INDEX idx_review_game_score ON review(game_id, score);                   -- Feature 4
```

### Rerun the measurements

1. Load the production database as above.
2. Allow `cs348_app` to read `performance_schema`. Only root can grant this, and Docker generated a random root password on the container's first start:

   ```bash
   ROOT_PW=$(docker compose logs mysql | grep -o 'GENERATED ROOT PASSWORD: .*' | cut -d' ' -f4)
   docker compose exec mysql mysql -uroot -p"$ROOT_PW" -e "GRANT SELECT ON performance_schema.* TO 'cs348_app'@'%'"
   ```

   If the log no longer has the password, run `docker compose down -v`, then `docker compose up -d`, and load the production database again.
3. Run the measurements:

   ```bash
   docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348 < sql/perf-production.sql > sql/perf-production.out
   ```

   On Windows PowerShell:

   ```powershell
   Get-Content sql/perf-production.sql | docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348 | Out-File -Encoding utf8 sql/perf-production.out
   ```

The file changes indexes while it runs and finishes with the `sql/schema.sql` indexes.

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
| 2. Upcoming releases on my platforms, excluding games already in my library | Yes | Yes | Yes |
| 3. View a library, add a game, and update status/hours | Yes | Yes | Yes |
| 4. Top-rated games in a genre by average review score | Yes | Yes | Yes |
| 5. Read a game's reviews, and write or edit a user's review | Yes | Yes | Yes |

All five features are implemented in two files:

- `backend/main.py`: one endpoint per feature, marked with a `# Feature N` comment. Feature 1 is `GET /api/search`, Feature 2 is `GET /api/upcoming`, Feature 3 is the three `/api/users/{user_id}/library` endpoints, Feature 4 is `GET /api/genre/{genre_id}/top`, and Feature 5 is `GET /api/games/{game_id}/reviews` and `PUT /api/users/{user_id}/reviews/{game_id}`.
- `frontend/src/App.jsx`: one component per feature, `Search`, `Upcoming`, `Library`, `Rankings` and `Reviews`.

Test steps and screenshots for each feature on the production database are in `docs/feature-tests.md`.