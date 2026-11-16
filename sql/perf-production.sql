-- R-c and Task 8: query plans and timings on the production database, measured as in the
-- spec appendix. Load sql/schema.sql and sql/load_production.sql first. cs348_app needs
-- SELECT on performance_schema (README, "Rerun the measurements").
--
-- Each query is the one the app sends, with the parameters of sql/test-production.sql filled
-- in: pixelpanda is user 1, Soma is game 9727, Shooter is genre 5, and Features 1 and 2 show
-- page 1. For each query: EXPLAIN ANALYZE (EXPLAIN for writes), one warm-up run, five timed runs,
-- then the five times and their median, read from events_statements_history in this same
-- session. TIMER_WAIT is in picoseconds, so /1e9 gives ms. Writes run in a transaction that
-- is rolled back.
--
-- Part 1 measures all five features with the sql/schema.sql indexes. Parts 2 and 3 are the
-- before/after index comparisons for Features 2 and 4. Part 4 is the too-many-indexes test.
-- The file changes indexes as it runs and ends with the sql/schema.sql indexes.
--
-- Run (all on one line):
--   docker compose exec -T mysql mysql -t -u cs348_app -pcs348_pass cs348
--     < sql/perf-production.sql > sql/perf-production.out

-- Reads the last five statements of this session whose text matches @pattern, with their median.
-- The patterns start with SELECT, INSERT or UPDATE, so the EXPLAIN, SET and EXECUTE statements
-- never match.
PREPARE timing FROM '
WITH runs AS (
    SELECT EVENT_ID, ROUND(TIMER_WAIT / 1e9, 3) AS ms
    FROM performance_schema.events_statements_history
    WHERE THREAD_ID = PS_CURRENT_THREAD_ID()
      AND SQL_TEXT LIKE ?
    ORDER BY EVENT_ID DESC
    LIMIT 5
)
SELECT EVENT_ID, ms, (SELECT ms FROM runs ORDER BY ms LIMIT 1 OFFSET 2) AS median_ms
FROM runs
ORDER BY EVENT_ID';

SELECT VERSION() AS mysql_version, CURDATE() AS today;

-- Fresh statistics after the load, so the optimizer plans from real row counts.
ANALYZE TABLE game, platform, genre, game_platform, game_genre, app_user, user_platform,
              library_entry, review;

-- ============================================================
-- Part 1: all five features, sql/schema.sql indexes
-- ============================================================

-- Features 2 and 4 with these indexes are the AFTER cases in Parts 2 and 3.

SELECT 'Feature 1a: title contains Soma' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE CONCAT('%', 'Soma', '%')
  AND (NULL IS NULL OR p.platform_id = NULL)
  AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg
                               WHERE gg.game_id = g.game_id AND gg.genre_id = NULL))
ORDER BY g.title, g.game_id, gp.release_date, platform
LIMIT 101 OFFSET 0;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', 'Soma', '%') AND (NULL IS NULL OR p.platform_id = NULL) AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = NULL)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', 'Soma', '%') AND (NULL IS NULL OR p.platform_id = NULL) AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = NULL)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', 'Soma', '%') AND (NULL IS NULL OR p.platform_id = NULL) AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = NULL)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', 'Soma', '%') AND (NULL IS NULL OR p.platform_id = NULL) AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = NULL)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', 'Soma', '%') AND (NULL IS NULL OR p.platform_id = NULL) AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = NULL)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', 'Soma', '%') AND (NULL IS NULL OR p.platform_id = NULL) AND (NULL IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = NULL)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;

SET @pattern = 'SELECT g.game_id%Soma%';
EXECUTE timing USING @pattern;


SELECT 'Feature 1b: PlayStation 4 (48), Adventure (31), empty title' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE CONCAT('%', '', '%')
  AND (48 IS NULL OR p.platform_id = 48)
  AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg
                             WHERE gg.game_id = g.game_id AND gg.genre_id = 31))
ORDER BY g.title, g.game_id, gp.release_date, platform
LIMIT 101 OFFSET 0;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', '', '%') AND (48 IS NULL OR p.platform_id = 48) AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = 31)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', '', '%') AND (48 IS NULL OR p.platform_id = 48) AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = 31)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', '', '%') AND (48 IS NULL OR p.platform_id = 48) AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = 31)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', '', '%') AND (48 IS NULL OR p.platform_id = 48) AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = 31)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', '', '%') AND (48 IS NULL OR p.platform_id = 48) AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = 31)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE g.title LIKE CONCAT('%', '', '%') AND (48 IS NULL OR p.platform_id = 48) AND (31 IS NULL OR EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id AND gg.genre_id = 31)) ORDER BY g.title, g.game_id, gp.release_date, platform LIMIT 101 OFFSET 0;

SET @pattern = 'SELECT g.game_id%p.platform_id = 48%';
EXECUTE timing USING @pattern;


SELECT 'Feature 3: read pixelpanda library' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at
FROM library_entry le
  JOIN game g ON g.game_id = le.game_id
WHERE le.user_id = 1
ORDER BY le.added_at DESC;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at FROM library_entry le JOIN game g ON g.game_id = le.game_id WHERE le.user_id = 1 ORDER BY le.added_at DESC;
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at FROM library_entry le JOIN game g ON g.game_id = le.game_id WHERE le.user_id = 1 ORDER BY le.added_at DESC;
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at FROM library_entry le JOIN game g ON g.game_id = le.game_id WHERE le.user_id = 1 ORDER BY le.added_at DESC;
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at FROM library_entry le JOIN game g ON g.game_id = le.game_id WHERE le.user_id = 1 ORDER BY le.added_at DESC;
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at FROM library_entry le JOIN game g ON g.game_id = le.game_id WHERE le.user_id = 1 ORDER BY le.added_at DESC;
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at FROM library_entry le JOIN game g ON g.game_id = le.game_id WHERE le.user_id = 1 ORDER BY le.added_at DESC;

SET @pattern = 'SELECT g.game_id, g.title, le.status%';
EXECUTE timing USING @pattern;


START TRANSACTION;

SELECT 'Feature 3: add a game to pixelpanda library' AS test;

EXPLAIN
INSERT INTO library_entry (user_id, game_id, status, hours_played)
VALUES (1, 9727, 'backlog', 0);

-- Warm-up, then five timed runs, each on a different game.
INSERT INTO library_entry (user_id, game_id, status, hours_played) VALUES (1, 9727, 'backlog', 0);
INSERT INTO library_entry (user_id, game_id, status, hours_played) VALUES (1, 1020, 'backlog', 0);
INSERT INTO library_entry (user_id, game_id, status, hours_played) VALUES (1, 17000, 'backlog', 0);
INSERT INTO library_entry (user_id, game_id, status, hours_played) VALUES (1, 114795, 'backlog', 0);
INSERT INTO library_entry (user_id, game_id, status, hours_played) VALUES (1, 27789, 'backlog', 0);
INSERT INTO library_entry (user_id, game_id, status, hours_played) VALUES (1, 24654, 'backlog', 0);

SET @pattern = 'INSERT INTO library_entry%';
EXECUTE timing USING @pattern;

SELECT 'Feature 3: update a library entry' AS test;

EXPLAIN
UPDATE library_entry
SET status = 'playing', hours_played = 12.5
WHERE user_id = 1 AND game_id = 9727;

-- Warm-up, then five timed runs, each on a different game.
UPDATE library_entry SET status = 'playing', hours_played = 12.5 WHERE user_id = 1 AND game_id = 9727;
UPDATE library_entry SET status = 'playing', hours_played = 12.5 WHERE user_id = 1 AND game_id = 1020;
UPDATE library_entry SET status = 'playing', hours_played = 12.5 WHERE user_id = 1 AND game_id = 17000;
UPDATE library_entry SET status = 'playing', hours_played = 12.5 WHERE user_id = 1 AND game_id = 114795;
UPDATE library_entry SET status = 'playing', hours_played = 12.5 WHERE user_id = 1 AND game_id = 27789;
UPDATE library_entry SET status = 'playing', hours_played = 12.5 WHERE user_id = 1 AND game_id = 24654;

SET @pattern = 'UPDATE library_entry%';
EXECUTE timing USING @pattern;

ROLLBACK;

SELECT 'Feature 5a: read the reviews of Soma' AS test;

EXPLAIN ANALYZE
SELECT u.username, r.score, r.body, r.created_at
FROM review r
  JOIN app_user u ON r.user_id = u.user_id
WHERE r.game_id = 9727
ORDER BY r.created_at DESC, u.username;

-- Warm-up, then five timed runs.
SELECT u.username, r.score, r.body, r.created_at FROM review r JOIN app_user u ON r.user_id = u.user_id WHERE r.game_id = 9727 ORDER BY r.created_at DESC, u.username;
SELECT u.username, r.score, r.body, r.created_at FROM review r JOIN app_user u ON r.user_id = u.user_id WHERE r.game_id = 9727 ORDER BY r.created_at DESC, u.username;
SELECT u.username, r.score, r.body, r.created_at FROM review r JOIN app_user u ON r.user_id = u.user_id WHERE r.game_id = 9727 ORDER BY r.created_at DESC, u.username;
SELECT u.username, r.score, r.body, r.created_at FROM review r JOIN app_user u ON r.user_id = u.user_id WHERE r.game_id = 9727 ORDER BY r.created_at DESC, u.username;
SELECT u.username, r.score, r.body, r.created_at FROM review r JOIN app_user u ON r.user_id = u.user_id WHERE r.game_id = 9727 ORDER BY r.created_at DESC, u.username;
SELECT u.username, r.score, r.body, r.created_at FROM review r JOIN app_user u ON r.user_id = u.user_id WHERE r.game_id = 9727 ORDER BY r.created_at DESC, u.username;

SET @pattern = 'SELECT u.username, r.score%';
EXECUTE timing USING @pattern;


START TRANSACTION;

SELECT 'Feature 5b: pixelpanda writes a review' AS test;

EXPLAIN
INSERT INTO review (user_id, game_id, score, body, created_at)
VALUES (1, 9727, 8, 'Great atmosphere.', NOW()) AS new
ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;

-- Warm-up, then five timed runs, each on a different game.
INSERT INTO review (user_id, game_id, score, body, created_at) VALUES (1, 9727, 8, 'Great atmosphere.', NOW()) AS new ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
INSERT INTO review (user_id, game_id, score, body, created_at) VALUES (1, 1020, 8, 'Great atmosphere.', NOW()) AS new ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
INSERT INTO review (user_id, game_id, score, body, created_at) VALUES (1, 17000, 8, 'Great atmosphere.', NOW()) AS new ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
INSERT INTO review (user_id, game_id, score, body, created_at) VALUES (1, 114795, 8, 'Great atmosphere.', NOW()) AS new ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
INSERT INTO review (user_id, game_id, score, body, created_at) VALUES (1, 27789, 8, 'Great atmosphere.', NOW()) AS new ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
INSERT INTO review (user_id, game_id, score, body, created_at) VALUES (1, 24654, 8, 'Great atmosphere.', NOW()) AS new ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;

SET @pattern = 'INSERT INTO review (%';
EXECUTE timing USING @pattern;

ROLLBACK;


-- ============================================================
-- Part 2: Feature 2, game_platform(platform_id, release_date)
-- ============================================================

-- Before: the plain platform_id index MySQL creates for the foreign key.
-- It is created first because MySQL will not drop the only index a foreign key can use.
CREATE INDEX platform_id ON game_platform(platform_id);
DROP INDEX idx_gp_platform_date ON game_platform;
ANALYZE TABLE game_platform;

SELECT 'Feature 2b BEFORE: pixelpanda upcoming releases' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM user_platform up
  JOIN platform p ON up.platform_id = p.platform_id
  JOIN game_platform gp ON p.platform_id = gp.platform_id
  JOIN game g ON gp.game_id = g.game_id
WHERE up.user_id = 1
  AND gp.release_date > CURDATE()
  AND NOT EXISTS (SELECT * FROM library_entry le
                  WHERE le.user_id = up.user_id AND le.game_id = g.game_id)
ORDER BY gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;

SET @pattern = 'SELECT g.game_id%FROM user_platform%';
EXECUTE timing USING @pattern;


SELECT 'Feature 2a BEFORE: all upcoming releases' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL
ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;

SET @pattern = 'SELECT g.game_id%FROM game g%CURDATE() OR%';
EXECUTE timing USING @pattern;


-- After: back to the sql/schema.sql index.
CREATE INDEX idx_gp_platform_date ON game_platform(platform_id, release_date);
DROP INDEX platform_id ON game_platform;
ANALYZE TABLE game_platform;

SELECT 'Feature 2b AFTER: pixelpanda upcoming releases' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM user_platform up
  JOIN platform p ON up.platform_id = p.platform_id
  JOIN game_platform gp ON p.platform_id = gp.platform_id
  JOIN game g ON gp.game_id = g.game_id
WHERE up.user_id = 1
  AND gp.release_date > CURDATE()
  AND NOT EXISTS (SELECT * FROM library_entry le
                  WHERE le.user_id = up.user_id AND le.game_id = g.game_id)
ORDER BY gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM user_platform up JOIN platform p ON up.platform_id = p.platform_id JOIN game_platform gp ON p.platform_id = gp.platform_id JOIN game g ON gp.game_id = g.game_id WHERE up.user_id = 1 AND gp.release_date > CURDATE() AND NOT EXISTS (SELECT * FROM library_entry le WHERE le.user_id = up.user_id AND le.game_id = g.game_id) ORDER BY gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;

SET @pattern = 'SELECT g.game_id%FROM user_platform%';
EXECUTE timing USING @pattern;


SELECT 'Feature 2a AFTER: all upcoming releases' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL
ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date FROM game g JOIN game_platform gp ON g.game_id = gp.game_id JOIN platform p ON gp.platform_id = p.platform_id WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform LIMIT 101 OFFSET 0;

SET @pattern = 'SELECT g.game_id%FROM game g%CURDATE() OR%';
EXECUTE timing USING @pattern;



-- ============================================================
-- Part 3: Feature 4, review(game_id, score)
-- ============================================================

-- Before: a plain game_id index, the one MySQL creates for the foreign key.
CREATE INDEX game_id ON review(game_id);
DROP INDEX idx_review_game_score ON review;
ANALYZE TABLE review;

SELECT 'Feature 4 BEFORE: top 10 Shooter (genre 5) games' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating,
       COUNT(r.score) AS rating_count
FROM game g
  JOIN game_genre gg ON g.game_id = gg.game_id
  JOIN review r ON g.game_id = r.game_id
WHERE gg.genre_id = 5
  AND r.score IS NOT NULL
GROUP BY g.game_id, g.title
ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id
LIMIT 10;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;

SET @pattern = 'SELECT g.game_id%ROUND(AVG(r.score)%';
EXECUTE timing USING @pattern;


-- After: back to the sql/schema.sql index.
CREATE INDEX idx_review_game_score ON review(game_id, score);
DROP INDEX game_id ON review;
ANALYZE TABLE review;

SELECT 'Feature 4 AFTER: top 10 Shooter (genre 5) games' AS test;

EXPLAIN ANALYZE
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating,
       COUNT(r.score) AS rating_count
FROM game g
  JOIN game_genre gg ON g.game_id = gg.game_id
  JOIN review r ON g.game_id = r.game_id
WHERE gg.genre_id = 5
  AND r.score IS NOT NULL
GROUP BY g.game_id, g.title
ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id
LIMIT 10;

-- Warm-up, then five timed runs.
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;
SELECT g.game_id, g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count FROM game g JOIN game_genre gg ON g.game_id = gg.game_id JOIN review r ON g.game_id = r.game_id WHERE gg.genre_id = 5 AND r.score IS NOT NULL GROUP BY g.game_id, g.title ORDER BY average_rating DESC, rating_count DESC, g.title, g.game_id LIMIT 10;

SET @pattern = 'SELECT g.game_id%ROUND(AVG(r.score)%';
EXECUTE timing USING @pattern;



-- ============================================================
-- Part 4: too many indexes
-- ============================================================

-- Copies all reviews into review_copy, first with the schema.sql indexes (the primary key and
-- (game_id, score)), then with four extra indexes that none of the five features uses.
-- Each run empties the copy first.
DROP TABLE IF EXISTS review_copy;
CREATE TABLE review_copy LIKE review;

SELECT 'Copy 58,389 reviews, schema.sql indexes' AS test;

TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;

SET @pattern = 'INSERT INTO review_copy%';
EXECUTE timing USING @pattern;

CREATE INDEX x_score ON review_copy(score);
CREATE INDEX x_created ON review_copy(created_at);
CREATE INDEX x_user_score ON review_copy(user_id, score);
CREATE INDEX x_game_created ON review_copy(game_id, created_at);

SELECT 'Copy 58,389 reviews, four extra indexes' AS test;

TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;
TRUNCATE TABLE review_copy;
INSERT INTO review_copy SELECT * FROM review;

SET @pattern = 'INSERT INTO review_copy%';
EXECUTE timing USING @pattern;

DROP TABLE review_copy;
DEALLOCATE PREPARE timing;
