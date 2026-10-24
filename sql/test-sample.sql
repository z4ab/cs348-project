-- SQL for the four Milestone 1 features, run over the sample database.
-- Reload the sample first (schema.sql, then load_sample.sql), then run this file (see README).
-- Each feature runs the sample query from the report. Features 1 and 3 also run their
-- query template with other parameters. Features 1 and 3 are the queries the app sends.

-- Feature 1: Game search and filtering

SELECT 'Feature 1a: report sample, title contains "Soma"' AS test;
SELECT g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE '%Soma%'
ORDER BY g.title, gp.release_date, p.name;

SELECT 'Feature 1b: template, any title, on PlayStation 4 (48), genre Adventure (31)' AS test;
SET @q = '', @platform = 48, @genre = 31;
SELECT DISTINCT g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE CONCAT('%', @q, '%')
  AND (@platform IS NULL OR p.platform_id = @platform)
  AND (@genre IS NULL OR EXISTS (SELECT * FROM game_genre gg
                                 WHERE gg.game_id = g.game_id AND gg.genre_id = @genre))
ORDER BY g.title, gp.release_date, platform;

-- Feature 2: Upcoming game releases

SELECT 'Feature 2: report sample, pixelpanda, releases since 2025-01-01' AS test;
SELECT g.title, p.name AS platform, gp.release_date
FROM user_platform up
  JOIN platform p ON up.platform_id = p.platform_id
  JOIN game_platform gp ON p.platform_id = gp.platform_id
  JOIN game g ON gp.game_id = g.game_id
WHERE up.user_id = (SELECT user_id FROM app_user WHERE username = 'pixelpanda')
  AND gp.release_date >= '2025-01-01'
  AND NOT EXISTS (SELECT 1 FROM library_entry le
                  WHERE le.user_id = up.user_id AND le.game_id = g.game_id)
ORDER BY gp.release_date, g.title, p.name;

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
