# CS 348 Fall 2026 Course Project

MySQL + FastAPI (raw SQL via `pymysql`) + React (Vite).

- `sql/`: database scripts
- `backend/`: FastAPI app
- `frontend/`: React app (proxies `/api` to the backend)

## Create and load the sample database

Needs MySQL 8+ running on `127.0.0.1:3306`.

```bash
mysql -u root -p < sql/setup_db.sql                  # once: database cs348 + user cs348_app
mysql -u cs348_app -pcs348_pass cs348 < sql/sample.sql  # create, load or reset the sample data
```

## Run

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

- List students: `SELECT uid, name, score FROM student ORDER BY uid`
- Add a student: `INSERT INTO student (uid, name, score) VALUES (...)` (duplicate uid shows an error)
