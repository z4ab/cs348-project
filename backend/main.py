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


# User picker: up to `limit` users whose username starts with q. q can't be empty, so
# this never returns all users. A prefix match can use the UNIQUE index on username.
@app.get("/api/users")
def search_users(q: str = Query(min_length=1), limit: int = Query(10, ge=1, le=50)):
    return fetch_all("""
        SELECT user_id, username
        FROM app_user
        WHERE username LIKE CONCAT(%s, '%%')
        ORDER BY username
        LIMIT %s""", (q, limit))


# Game picker for adding to a library: up to `limit` games whose title contains q.
# q can't be empty, so this never returns the whole table. year is the earliest release
# on any platform (NULL if none is known), to tell apart games with the same title.
@app.get("/api/games")
def search_game_titles(q: str = Query(min_length=1), limit: int = Query(10, ge=1, le=50)):
    return fetch_all("""
        SELECT g.game_id, g.title, YEAR(MIN(gp.release_date)) AS year
        FROM game g
          LEFT JOIN game_platform gp ON g.game_id = gp.game_id
        WHERE g.title LIKE CONCAT('%%', %s, '%%')
        GROUP BY g.game_id, g.title
        ORDER BY g.title, g.game_id
        LIMIT %s""", (q, limit))


PAGE_SIZE = 100


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
        (q, platform, platform, genre, genre, PAGE_SIZE + 1, (page - 1) * PAGE_SIZE))
    return {"results": rows[:PAGE_SIZE], "has_next": len(rows) > PAGE_SIZE}

# Feature 2: upcoming releases, 100 rows per page, paged the same way as Feature 1.
# Without user_id: every upcoming release on any platform, with undated releases (TBA) last.
# With user_id: releases on that user's platforms, leaving out games already in their library.
@app.get("/api/upcoming")
def upcoming_games(user_id: int | None = None, page: int = Query(1, ge=1)):
    if user_id is None:
        rows = fetch_all("""
            SELECT g.game_id, g.title, p.name AS platform, gp.release_date
            FROM game g
              JOIN game_platform gp ON g.game_id = gp.game_id
              JOIN platform p ON gp.platform_id = p.platform_id
            WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL
            ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform
            LIMIT %s OFFSET %s""",
            (PAGE_SIZE + 1, (page - 1) * PAGE_SIZE))
    else:
        rows = fetch_all("""
            SELECT g.game_id, g.title, p.name AS platform, gp.release_date
            FROM user_platform up
              JOIN platform p ON up.platform_id = p.platform_id
              JOIN game_platform gp ON p.platform_id = gp.platform_id
              JOIN game g ON gp.game_id = g.game_id
            WHERE up.user_id = %s
              AND gp.release_date > CURDATE()
              AND NOT EXISTS (SELECT * FROM library_entry le
                              WHERE le.user_id = up.user_id AND le.game_id = g.game_id)
            ORDER BY gp.release_date, g.title, g.game_id, platform
            LIMIT %s OFFSET %s""",
            (user_id, PAGE_SIZE + 1, (page - 1) * PAGE_SIZE))
    return {"results": rows[:PAGE_SIZE], "has_next": len(rows) > PAGE_SIZE}

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
        SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating,
        COUNT(r.score) AS rating_count
        FROM game g JOIN game_genre gg ON g.game_id = gg.game_id
        JOIN review r ON g.game_id = r.game_id
        WHERE gg.genre_id = %s AND r.score IS NOT NULL
        GROUP BY g.game_id, g.title
        ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
        """, (genre_id,)
    )


# Feature 5: read a game's reviews, and write or edit a user's review of it.
# Newest first. user_id lets the frontend find and prefill a user's existing review.
@app.get("/api/games/{game_id}/reviews")
def get_reviews(game_id: int):
    return fetch_all("""
        SELECT r.user_id, u.username, r.score, r.body, r.created_at
        FROM review r
        JOIN app_user u ON r.user_id = u.user_id
        WHERE r.game_id = %s
        ORDER BY r.created_at DESC, u.username""", (game_id,))


class ReviewIn(BaseModel):
    score: int | None = None
    body: str | None = None


REVIEW_BODY_MAX = 2000  # review.body is VARCHAR(2000)


# A user has at most one review per game, so one INSERT ... ON DUPLICATE KEY UPDATE
# covers writing and editing. An edit replaces the score and text and moves created_at
# to now. The checks mirror the review table's CHECK constraints, so a bad review gets
# a 400 with a message instead of a database error.
@app.put("/api/users/{user_id}/reviews/{game_id}")
def save_review(user_id: int, game_id: int, r: ReviewIn):
    body = r.body.strip() if r.body else None
    if not body:
        body = None
    if r.score is not None and not 1 <= r.score <= 10:
        raise HTTPException(400, "Score must be between 1 and 10")
    if body is not None and len(body) > REVIEW_BODY_MAX:
        raise HTTPException(400, f"Review text must be at most {REVIEW_BODY_MAX} characters")
    if r.score is None and body is None:
        raise HTTPException(400, "A review needs a score, text, or both")
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.execute("""
                INSERT INTO review (user_id, game_id, score, body, created_at)
                VALUES (%s, %s, %s, %s, NOW()) AS new
                ON DUPLICATE KEY UPDATE score = new.score, body = new.body,
                                        created_at = new.created_at""",
                (user_id, game_id, r.score, body))
    except (pymysql.IntegrityError, pymysql.DataError) as err:
        # 1452: no such user_id or game_id. 1264: an id too large for INT, so also unknown.
        if err.args[0] in (1452, 1264):
            raise HTTPException(404, "Unknown user or game")
        raise
