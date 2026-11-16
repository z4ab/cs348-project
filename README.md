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
- `data/production/`: larger production dataset, one CSV per table
- `data/raw/steamspy.json`: cached SteamSpy responses
- `games.json`: saved IGDB pull of 20 games
- `scripts/build_sample.py`: builds the sample dataset
- `scripts/build_production.py`: builds the larger production dataset
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

The production dataset contains the same real game metadata together with a much larger generated set of users, libraries, platforms, and reviews for production testing.

The current generated dataset contains approximately:

- 5,000 users
- 9,926 user-platform relationships
- 49,816 library entries
- 23,377 reviews

Build the production CSV files:

```bash
python scripts/build_production.py
```

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

Production queries were inspected with MySQL `EXPLAIN` and `EXPLAIN ANALYZE`.

Example execution times from local Docker testing were:

- Feature 1 game search: approximately `0.213 ms`
- Feature 2 upcoming releases: approximately `0.083 ms`
- Feature 3 library lookup: approximately `0.037 ms`
- Feature 4 top-rated games before optimization: approximately `7.27 ms`

Feature 4 processes thousands of review rows to calculate averages and counts, so an additional covering index was added:

```sql
CREATE INDEX idx_review_game_score ON review(game_id, score);
```

After adding this index, Feature 4 used a covering index lookup and its measured execution time decreased from approximately `7.27 ms` to `3.07 ms` in the local test environment.

The index is included in `sql/schema.sql` so it is recreated whenever the database is rebuilt.

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