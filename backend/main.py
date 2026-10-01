import pymysql
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()


def connect():
    return pymysql.connect(host="127.0.0.1", user="cs348_app", password="cs348_pass",
                           database="cs348", cursorclass=pymysql.cursors.DictCursor, autocommit=True)


class Student(BaseModel):
    uid: int
    name: str
    score: float | None = None


@app.get("/api/students")
def list_students():
    with connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT uid, name, score FROM student ORDER BY uid")
        return cur.fetchall()


@app.post("/api/students")
def add_student(s: Student):
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO student (uid, name, score) VALUES (%s, %s, %s)", (s.uid, s.name, s.score))
    except pymysql.IntegrityError:
        raise HTTPException(409, f"Student {s.uid} already exists")
