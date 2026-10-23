-- SQL for the four Milestone 1 features, run over the sample database.
-- Reload the sample first (schema.sql, then load_sample.sql), then from the repo root:
--   mysql -t -u cs348_app -p cs348 < sql/test-sample.sql > sql/test-sample.out
-- Each feature sets its parameters as user variables, then runs the same query the app sends.

-- Feature 1: Search games
-- Title substring, plus an optional platform and genre (NULL means any).

SELECT 'Feature 1a: title contains "dark"' AS test;
SET @q = 'dark', @platform = NULL, @genre = NULL;
SELECT g.game_id, g.title,
       (SELECT MIN(gp.release_date) FROM game_platform gp WHERE gp.game_id = g.game_id) AS first_release
FROM game g
WHERE g.title LIKE CONCAT('%', @q, '%')
  AND (@platform IS NULL OR EXISTS (SELECT 1 FROM game_platform gp
                                    WHERE gp.game_id = g.game_id AND gp.platform_id = @platform))
  AND (@genre IS NULL OR EXISTS (SELECT 1 FROM game_genre gg
                                 WHERE gg.game_id = g.game_id AND gg.genre_id = @genre))
ORDER BY g.title;

SELECT 'Feature 1b: any title, on PlayStation 4 (48), genre Adventure (31)' AS test;
SET @q = '', @platform = 48, @genre = 31;
SELECT g.game_id, g.title,
       (SELECT MIN(gp.release_date) FROM game_platform gp WHERE gp.game_id = g.game_id) AS first_release
FROM game g
WHERE g.title LIKE CONCAT('%', @q, '%')
  AND (@platform IS NULL OR EXISTS (SELECT 1 FROM game_platform gp
                                    WHERE gp.game_id = g.game_id AND gp.platform_id = @platform))
  AND (@genre IS NULL OR EXISTS (SELECT 1 FROM game_genre gg
                                 WHERE gg.game_id = g.game_id AND gg.genre_id = @genre))
ORDER BY g.title;

-- Feature 2: Releases on my platforms
-- Releases on or after a date, on platforms the user owns. The app passes today's date.

SELECT 'Feature 2: releases since 2016-01-01 on backlogbeth''s (user 3) platforms' AS test;
SET @user = 3, @from = '2016-01-01';
SELECT g.title, p.name AS platform, gp.release_date
FROM user_platform up
JOIN game_platform gp ON gp.platform_id = up.platform_id
JOIN game g ON g.game_id = gp.game_id
JOIN platform p ON p.platform_id = gp.platform_id
WHERE up.user_id = @user AND gp.release_date >= @from
ORDER BY gp.release_date, g.title;

-- Feature 4: Genre leaderboard
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

-- Feature 3: Add or update a library entry
-- Adding a game already in the library updates its status and hours instead.
-- Runs last because it modifies the data.

SELECT 'Feature 3a: pixelpanda (user 1) adds Soma (9727) to backlog' AS test;
SET @user = 1, @game = 9727, @status = 'backlog', @hours = 0, @now = '2026-10-23 12:00:00';
INSERT INTO library_entry (user_id, game_id, status, hours_played, added_at)
VALUES (@user, @game, @status, COALESCE(@hours, 0), @now) AS new
ON DUPLICATE KEY UPDATE status = new.status, hours_played = COALESCE(@hours, library_entry.hours_played);

SELECT 'Feature 3b: pixelpanda starts Soma, 4.5 hours played' AS test;
SET @user = 1, @game = 9727, @status = 'playing', @hours = 4.5, @now = '2026-10-23 18:00:00';
INSERT INTO library_entry (user_id, game_id, status, hours_played, added_at)
VALUES (@user, @game, @status, COALESCE(@hours, 0), @now) AS new
ON DUPLICATE KEY UPDATE status = new.status, hours_played = COALESCE(@hours, library_entry.hours_played);

SELECT 'Feature 3c: pixelpanda''s library' AS test;
SET @user = 1;
SELECT g.game_id, g.title, le.status, le.hours_played, le.added_at
FROM library_entry le
JOIN game g ON g.game_id = le.game_id
WHERE le.user_id = @user
ORDER BY le.added_at DESC;
