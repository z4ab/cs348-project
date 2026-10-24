-- SQL for the four Milestone 1 features, run over the sample database.
-- Reload the sample first (schema.sql, then load_sample.sql), then run this file (see README).
-- Features 1, 2 and 4 set their parameters as user variables, then run the query template.
-- Features 1 and 3 are the queries the app sends.

-- Feature 1: Game search and filtering
-- One row per game and platform. Title substring, plus an optional platform and genre (NULL means any).

SELECT 'Feature 1a: title contains "Soma"' AS test;
SET @q = 'Soma', @platform = NULL, @genre = NULL;
SELECT DISTINCT g.title, p.name AS platform, gp.release_date
FROM game g
  JOIN game_platform gp ON g.game_id = gp.game_id
  JOIN platform p ON gp.platform_id = p.platform_id
WHERE g.title LIKE CONCAT('%', @q, '%')
  AND (@platform IS NULL OR p.platform_id = @platform)
  AND (@genre IS NULL OR EXISTS (SELECT * FROM game_genre gg
                                 WHERE gg.game_id = g.game_id AND gg.genre_id = @genre))
ORDER BY g.title, gp.release_date, platform;

SELECT 'Feature 1b: any title, on PlayStation 4 (48), genre Adventure (31)' AS test;
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
-- Releases on or after a date, on platforms the user owns, leaving out games already in their library.

SELECT 'Feature 2: releases since 2016-01-01 on backlogbeth''s platforms, not in their library' AS test;
SET @user = (SELECT user_id FROM app_user WHERE username = 'backlogbeth'), @from = '2016-01-01';
SELECT g.title, p.name AS platform, gp.release_date
FROM user_platform up
  JOIN platform p ON up.platform_id = p.platform_id
  JOIN game_platform gp ON p.platform_id = gp.platform_id
  JOIN game g ON gp.game_id = g.game_id
WHERE up.user_id = @user
  AND gp.release_date >= @from
  AND NOT EXISTS (SELECT * FROM library_entry le
                  WHERE le.user_id = up.user_id AND le.game_id = g.game_id)
ORDER BY gp.release_date, g.title, p.name;

-- Feature 3: Personal game library management
-- Each change runs in a transaction that is rolled back, so this file leaves the data unchanged.

SELECT 'Feature 3a: pixelpanda updates Darksiders to playing, 83.0 hours' AS test;
START TRANSACTION;
UPDATE library_entry
SET status = 'playing',
    hours_played = 83.0
WHERE user_id = (SELECT user_id FROM app_user WHERE username = 'pixelpanda')
  AND game_id = (SELECT game_id FROM game WHERE title = 'Darksiders');
SELECT u.username, g.title, le.status, le.hours_played
FROM library_entry le
  JOIN app_user u ON le.user_id = u.user_id
  JOIN game g ON le.game_id = g.game_id
WHERE u.username = 'pixelpanda'
  AND g.title = 'Darksiders';
ROLLBACK;

SELECT 'Feature 3b: pixelpanda adds Soma to their backlog' AS test;
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

-- Feature 4: Game ratings and rankings by genre
-- Games in a genre ranked by total hours our users played, with average review score
-- and SteamSpy owner range. Hours and scores are aggregated per game before the join
-- so library entries and reviews do not multiply each other.

SELECT 'Feature 4: Adventure (31) leaderboard' AS test;
SET @genre = 31;
WITH play AS (
  SELECT game_id, SUM(hours_played) AS total_hours, COUNT(*) AS players
  FROM library_entry GROUP BY game_id
), score AS (
  SELECT game_id, ROUND(AVG(score), 1) AS avg_score, COUNT(score) AS ratings
  FROM review GROUP BY game_id
)
SELECT g.title, COALESCE(play.total_hours, 0) AS total_hours, COALESCE(play.players, 0) AS players,
       score.avg_score, COALESCE(score.ratings, 0) AS ratings,
       g.steam_owners_low, g.steam_owners_high
FROM game_genre gg
JOIN game g ON g.game_id = gg.game_id
LEFT JOIN play ON play.game_id = g.game_id
LEFT JOIN score ON score.game_id = g.game_id
WHERE gg.genre_id = @genre
ORDER BY total_hours DESC, g.title;
