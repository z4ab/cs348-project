from datetime import datetime
from typing import Literal

import pymysql
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI()


def connect():
    return pymysql.connect(host="127.0.0.1", user="cs348_app", password="cs348_pass",
                           database="cs348", cursorclass=pymysql.cursors.DictCursor, autocommit=True)


def fetch_all(sql, params=()):
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


@app.get("/api/platforms")
def list_platforms():
    return fetch_all("SELECT platform_id, name FROM platform ORDER BY name")


@app.get("/api/genres")
def list_genres():
    return fetch_all("SELECT genre_id, name FROM genre ORDER BY name")


@app.get("/api/users")
def list_users():
    return fetch_all("SELECT user_id, username FROM app_user ORDER BY username")


# Feature 1: search games by title, with optional platform and genre filters.
@app.get("/api/games")
def search_games(q: str = "", platform: int | None = None, genre: int | None = None):
    return fetch_all("""
        SELECT g.game_id, g.title,
               (SELECT MIN(gp.release_date) FROM game_platform gp WHERE gp.game_id = g.game_id) AS first_release
        FROM game g
        WHERE g.title LIKE CONCAT('%%', %s, '%%')
          AND (%s IS NULL OR EXISTS (SELECT 1 FROM game_platform gp
                                     WHERE gp.game_id = g.game_id AND gp.platform_id = %s))
          AND (%s IS NULL OR EXISTS (SELECT 1 FROM game_genre gg
                                     WHERE gg.game_id = g.game_id AND gg.genre_id = %s))
        ORDER BY g.title""", (q, platform, platform, genre, genre))


# Feature 3: view a user's library, and add or update an entry in it.
@app.get("/api/users/{user_id}/library")
def get_library(user_id: int):
    return fetch_all("""
        SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at
        FROM library_entry le
        JOIN game g ON g.game_id = le.game_id
        WHERE le.user_id = %s
        ORDER BY le.added_at DESC""", (user_id,))


class LibraryEntry(BaseModel):
    game_id: int
    status: Literal["backlog", "playing", "completed"]
    hours_played: float | None = Field(None, ge=0, le=99999.9)  # None keeps the stored hours


@app.post("/api/users/{user_id}/library")
def save_library_entry(user_id: int, e: LibraryEntry):
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.execute("""
                INSERT INTO library_entry (user_id, game_id, status, hours_played, added_at)
                VALUES (%s, %s, %s, COALESCE(%s, 0), %s) AS new
                ON DUPLICATE KEY UPDATE status = new.status, hours_played = COALESCE(%s, library_entry.hours_played)""",
                        (user_id, e.game_id, e.status, e.hours_played, datetime.now(), e.hours_played))
    except pymysql.IntegrityError:
        raise HTTPException(404, "Unknown user or game")
