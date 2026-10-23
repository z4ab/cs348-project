# CS 348 Fall 2026 Course Project: Video Game Tracker

MySQL + FastAPI (raw SQL via `pymysql`) + React (Vite).

- `sql/`: database scripts
  - `setup_db.sql`: creates the `cs348` database and `cs348_app` user (run once as root)
  - `schema.sql`: creates the tables and constraints
  - `load_sample.sql`: loads `data/sample/*.csv`
  - `test-sample.sql`, `test-sample.out`: feature queries and their output on the sample database
- `data/sample/`: sample dataset, one CSV per table
- `data/raw/steamspy.json`: cached SteamSpy responses
- `games.json`: saved IGDB pull of 20 games
- `scripts/build_sample.py`: builds `data/sample/` from `games.json` and SteamSpy
- `backend/`: FastAPI app
- `frontend/`: React app (proxies `/api` to the backend)

## Create and load the sample database

Needs MySQL 8+ running on `127.0.0.1:3306`. Run from the repository root.

```bash
mysql -u root -p < sql/setup_db.sql                                         # once: database, user, local_infile
mysql -u cs348_app -pcs348_pass cs348 < sql/schema.sql                      # create (or reset) the tables
mysql --local-infile=1 -u cs348_app -pcs348_pass cs348 < sql/load_sample.sql  # load the CSVs
```

To rebuild the CSVs, run `python scripts/build_sample.py`. SteamSpy responses are cached, so this needs no network.

## Run the feature queries

Reload the sample database (the two commands above), then:

```bash
mysql -t -u cs348_app -pcs348_pass cs348 < sql/test-sample.sql > sql/test-sample.out
```

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

Open http://localhost:5173. On macOS/Linux use `.venv/bin/` instead of `.venv/Scripts/`.

## Features

| Feature | In the app | In `test-sample.sql` |
|---|---|---|
| 1. Search games by title, platform and genre | Yes | Yes |
| 2. Releases on my platforms since a date | No | Yes |
| 3. Add or update a library entry, view a library | Yes | Yes |
| 4. Genre leaderboard by hours played, with review score and Steam owners | No | Yes |
