-- SQL for Features 1-5, run over the sample database.
-- Reload the sample first (schema.sql, then load_sample.sql), then run this file (see README).
-- Each feature runs the sample query from the report. Features 1, 3 and 5 also run their
-- query template with other parameters. Features 1-4 are the queries the app sends.
-- Features 1 and 2 return 100 rows per page. They fetch 101 so the app can tell whether
-- another page follows. The samples show page 1 (OFFSET 0).

-- Feature 1: Game search and filtering

SELECT 'Feature 1a: report sample, title contains "Soma"' AS test;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE '%Soma%'
ORDER BY g.title, g.game_id, gp.release_date, platform
LIMIT 101 OFFSET 0;

SELECT 'Feature 1b: template, any title, on PlayStation 4 (48), genre Adventure (31)' AS test;
SET @q = '', @platform = 48, @genre = 31;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE CONCAT('%', @q, '%')
  AND (@platform IS NULL OR p.platform_id = @platform)
  AND (@genre IS NULL OR EXISTS (SELECT * FROM game_genre gg
                                 WHERE gg.game_id = g.game_id AND gg.genre_id = @genre))
ORDER BY g.title, g.game_id, gp.release_date, platform
LIMIT 101 OFFSET 0;

-- Feature 2: Upcoming game releases

-- The app compares release_date with CURDATE(). No sample release is in the future, so the
-- sample fixes "today" at 2015-01-01 to return rows.
SELECT 'Feature 2: report sample, pixelpanda, releases after 2015-01-01' AS test;
SELECT g.game_id, g.title, p.name AS platform, gp.release_date
FROM user_platform up
  JOIN platform p ON up.platform_id = p.platform_id
  JOIN game_platform gp ON p.platform_id = gp.platform_id
  JOIN game g ON gp.game_id = g.game_id
WHERE up.user_id = (SELECT user_id FROM app_user WHERE username = 'pixelpanda')
  AND gp.release_date > '2015-01-01'
  AND NOT EXISTS (SELECT * FROM library_entry le
                  WHERE le.user_id = up.user_id AND le.game_id = g.game_id)
ORDER BY gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;

-- Feature 3: Personal game library management
-- Each change runs in a transaction that is rolled back, so this file leaves the data unchanged.

SELECT 'Feature 3a: report sample, pixelpanda updates Darksiders to playing, 91.0 hours' AS test;
START TRANSACTION;
UPDATE library_entry
SET status = 'playing',
    hours_played = 91.0
WHERE user_id = (SELECT user_id FROM app_user WHERE username = 'pixelpanda')
  AND game_id = (SELECT game_id FROM game WHERE title = 'Darksiders');
SELECT u.username, g.title, le.status, le.hours_played
FROM library_entry le
  JOIN app_user u ON le.user_id = u.user_id
  JOIN game g ON le.game_id = g.game_id
WHERE u.username = 'pixelpanda'
  AND g.title = 'Darksiders';
ROLLBACK;

SELECT 'Feature 3b: INSERT template, pixelpanda adds Soma to their backlog' AS test;
START TRANSACTION;
INSERT INTO library_entry (user_id, game_id, status, hours_played)
VALUES ((SELECT user_id FROM app_user WHERE username = 'pixelpanda'),
        (SELECT game_id FROM game WHERE title = 'Soma'),
        'backlog', 0);
SELECT u.username, g.title, le.status, le.hours_played
FROM library_entry le
  JOIN app_user u ON le.user_id = u.user_id
  JOIN game g ON le.game_id = g.game_id
WHERE u.username = 'pixelpanda'
ORDER BY g.title;
ROLLBACK;

-- Feature 4: Game ratings and rankings

SELECT 'Feature 4: report sample, top-rated Shooter games' AS test;
SELECT g.title, ROUND(AVG(r.score), 2) AS average_rating, COUNT(r.score) AS rating_count
FROM game g
  JOIN game_genre gg ON g.game_id = gg.game_id
  JOIN genre ge ON gg.genre_id = ge.genre_id
  JOIN review r ON g.game_id = r.game_id
WHERE ge.name = 'Shooter'
  AND r.score IS NOT NULL
GROUP BY g.game_id, g.title
ORDER BY average_rating DESC, rating_count DESC, g.title
LIMIT 10;

-- Feature 5: Game reviews
-- A user has at most one review per game. Writing a review the user already has replaces it,
-- so one INSERT ... ON DUPLICATE KEY UPDATE covers both writing and editing.
-- The app passes the current time as created_at. The samples use fixed times so the output
-- is the same on every run. Writes are rolled back, as in Feature 3.

SELECT 'Feature 5a: report sample, read the reviews of Lost Ark' AS test;
SELECT u.username, r.score, r.body, r.created_at
FROM review r
  JOIN app_user u ON r.user_id = u.user_id
WHERE r.game_id = (SELECT game_id FROM game WHERE title = 'Lost Ark')
ORDER BY r.created_at DESC, u.username;

SELECT 'Feature 5b: report sample, pixelpanda writes a new review of Lost Ark' AS test;
START TRANSACTION;
INSERT INTO review (user_id, game_id, score, body, created_at)
VALUES ((SELECT user_id FROM app_user WHERE username = 'pixelpanda'),
        (SELECT game_id FROM game WHERE title = 'Lost Ark'),
        8, 'Great with friends.', '2026-11-01 12:00:00') AS new
ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
SELECT u.username, r.score, r.body, r.created_at
FROM review r
  JOIN app_user u ON r.user_id = u.user_id
WHERE r.game_id = (SELECT game_id FROM game WHERE title = 'Lost Ark')
ORDER BY r.created_at DESC, u.username;
ROLLBACK;

SELECT 'Feature 5c: template, speedrunsam edits their Lost Ark review to add a score' AS test;
START TRANSACTION;
SET @user = (SELECT user_id FROM app_user WHERE username = 'speedrunsam'),
    @game = (SELECT game_id FROM game WHERE title = 'Lost Ark'),
    @score = 4, @body = 'Gave up halfway. The grind is too long.',
    @created_at = '2026-11-02 12:00:00';
INSERT INTO review (user_id, game_id, score, body, created_at)
VALUES (@user, @game, @score, @body, @created_at) AS new
ON DUPLICATE KEY UPDATE score = new.score, body = new.body, created_at = new.created_at;
SELECT u.username, r.score, r.body, r.created_at
FROM review r
  JOIN app_user u ON r.user_id = u.user_id
WHERE r.game_id = @game
ORDER BY r.created_at DESC, u.username;
ROLLBACK;
