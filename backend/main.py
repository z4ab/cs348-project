from typing import Literal

import pymysql
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

app = FastAPI()


def connect():
    # FOUND_ROWS makes an UPDATE report matched rows, so saving unchanged values is not a "not found".
    return pymysql.connect(host="127.0.0.1", user="cs348_app", password="cs348_pass",
                           database="cs348", cursorclass=pymysql.cursors.DictCursor, autocommit=True,
                           client_flag=pymysql.constants.CLIENT.FOUND_ROWS)


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


@app.get("/api/games")
def list_games():
    return fetch_all("SELECT game_id, title FROM game ORDER BY title")


SEARCH_PAGE_SIZE = 100


# Feature 1: search games by title, with optional platform and genre filters.
# One row per game and platform, with that platform's release date, 100 rows per page.
# It fetches one extra row to tell whether another page follows. game_id in the ORDER BY
# makes the order total, so two games with the same title cannot swap between pages.
@app.get("/api/search")
def search_games(q: str = "", platform: int | None = None, genre: int | None = None,
                 page: int = Query(1, ge=1)):
    rows = fetch_all("""
        SELECT g.game_id, g.title, p.name AS platform, gp.release_date
        FROM game g
          JOIN game_platform gp ON g.game_id = gp.game_id
          JOIN platform p ON gp.platform_id = p.platform_id
        WHERE g.title LIKE CONCAT('%%', %s, '%%')
          AND (%s IS NULL OR p.platform_id = %s)
          AND (%s IS NULL OR EXISTS (SELECT * FROM game_genre gg
                                     WHERE gg.game_id = g.game_id AND gg.genre_id = %s))
        ORDER BY g.title, g.game_id, gp.release_date, platform
        LIMIT %s OFFSET %s""",
        (q, platform, platform, genre, genre, SEARCH_PAGE_SIZE + 1, (page - 1) * SEARCH_PAGE_SIZE))
    return {"results": rows[:SEARCH_PAGE_SIZE], "has_next": len(rows) > SEARCH_PAGE_SIZE}

# Feature 2: View upcoming games releases, with a way to filter on platforms that you own.
# 2a: View all upcoming releases
@app.get("/api/upcoming")
def upcoming_games(user_id: int | None = None):
    if (user_id is None): 
        return fetch_all(
            """
            SELECT g.title , p.name AS platform, gp.release_date 
            FROM game g JOIN game_platform gp ON g.game_id = gp.game_id 
            JOIN platform p ON gp.platform_id = p.platform_id 
            WHERE (gp.release_date > CURDATE() OR gp.release_date IS NULL) 
            ORDER BY gp.release_date, g.title, p.name;
            """
        )
    else:
        return fetch_all(
            """
            SELECT g.title, p.name AS platform, gp.release_date
            FROM user_platform up JOIN platform p ON 
            up.platform_id = p.platform_id
            JOIN game_platform gp ON p.platform_id = gp.platform_id
            JOIN game g ON gp.game_id = g.game_id
            WHERE up.user_id = %s
            AND gp.release_date > CURDATE()
            AND NOT EXISTS (
            SELECT *
            FROM library_entry le
            WHERE le.user_id = up.user_id
            AND le.game_id = g.game_id
            )
            ORDER BY gp.release_date, g.title, p.name;
            """, (user_id)
        )

# Feature 3: view a user's library, add a game to it, and update an entry.
@app.get("/api/users/{user_id}/library")
def get_library(user_id: int):
    return fetch_all("""
        SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at
        FROM library_entry le
        JOIN game g ON g.game_id = le.game_id
        WHERE le.user_id = %s
        ORDER BY le.added_at DESC""", (user_id,))


Status = Literal["backlog", "playing", "completed"]


class NewEntry(BaseModel):
    game_id: int
    status: Status
    hours_played: float = Field(0, ge=0, le=999999.9)


class EntryUpdate(BaseModel):
    status: Status
    hours_played: float = Field(ge=0, le=999999.9)


@app.post("/api/users/{user_id}/library")
def add_library_entry(user_id: int, e: NewEntry):
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.execute("""
                INSERT INTO library_entry (user_id, game_id, status, hours_played)
                VALUES (%s, %s, %s, %s)""", (user_id, e.game_id, e.status, e.hours_played))
    except pymysql.IntegrityError as err:
        if err.args[0] == 1062:  # duplicate (user_id, game_id)
            raise HTTPException(409, "Game is already in this library")
        raise HTTPException(404, "Unknown user or game")


@app.put("/api/users/{user_id}/library/{game_id}")
def update_library_entry(user_id: int, game_id: int, e: EntryUpdate):
    with connect() as conn, conn.cursor() as cur:
        cur.execute("""
            UPDATE library_entry
            SET status = %s, hours_played = %s
            WHERE user_id = %s AND game_id = %s""", (e.status, e.hours_played, user_id, game_id))
        if cur.rowcount == 0:
            raise HTTPException(404, "Game is not in this library")

# Feature 4: View the top rated games of a specific genre
@app.get("/api/genre/{genre_id}/top")
def top_ten_genre(genre_id: int):
    return fetch_all(
        """
        SELECT g.title, ROUND(AVG(r.score), 2) AS average_rating,
        COUNT(r.score) AS rating_count
        FROM game g JOIN game_genre gg ON g.game_id = gg.game_id
        JOIN review r ON g.game_id = r.game_id
        WHERE gg.genre_id = %s AND r.score IS NOT NULL
        GROUP BY g.game_id, g.title
        ORDER BY average_rating DESC, rating_count DESC, g.title LIMIT 10;
        """, (genre_id)
    )
    