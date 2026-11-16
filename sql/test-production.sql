-- SQL for the four project features, run over the production database.
-- Load sql/schema.sql and sql/load_production.sql before running this file.
-- Features 1 and 2 are the queries the app sends. They return 100 rows per page and fetch
-- 101 so the app can tell whether another page follows. These show page 1 (OFFSET 0).

-- ============================================================
-- Feature 1: Game search and filtering
-- ============================================================

SELECT 'Feature 1a: title contains "Soma"' AS test;

SELECT
    g.game_id,
    g.title,
    p.name AS platform,
    gp.release_date
FROM game g
JOIN game_platform gp
    ON g.game_id = gp.game_id
JOIN platform p
    ON gp.platform_id = p.platform_id
WHERE g.title LIKE '%Soma%'
ORDER BY g.title, g.game_id, gp.release_date, platform
LIMIT 101 OFFSET 0;


SELECT 'Feature 1b: PlayStation 4 (48), genre Adventure (31)' AS test;

SET @q = '';
SET @platform = 48;
SET @genre = 31;

SELECT
    g.game_id,
    g.title,
    p.name AS platform,
    gp.release_date
FROM game g
JOIN game_platform gp
    ON g.game_id = gp.game_id
JOIN platform p
    ON gp.platform_id = p.platform_id
WHERE g.title LIKE CONCAT('%', @q, '%')
  AND (@platform IS NULL OR p.platform_id = @platform)
  AND (
      @genre IS NULL
      OR EXISTS (
          SELECT *
          FROM game_genre gg
          WHERE gg.game_id = g.game_id
            AND gg.genre_id = @genre
      )
  )
ORDER BY g.title, g.game_id, gp.release_date, platform
LIMIT 101 OFFSET 0;


-- ============================================================
-- Feature 2: Upcoming game releases
-- ============================================================

SELECT 'Feature 2a: upcoming releases on any platform, undated (TBA) last' AS test;

SELECT
    g.game_id,
    g.title,
    p.name AS platform,
    gp.release_date
FROM game g
JOIN game_platform gp
    ON g.game_id = gp.game_id
JOIN platform p
    ON gp.platform_id = p.platform_id
WHERE gp.release_date > CURDATE() OR gp.release_date IS NULL
ORDER BY gp.release_date IS NULL, gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;


SELECT 'Feature 2b: upcoming releases for pixelpanda after today' AS test;

SELECT
    g.game_id,
    g.title,
    p.name AS platform,
    gp.release_date
FROM user_platform up
JOIN platform p
    ON up.platform_id = p.platform_id
JOIN game_platform gp
    ON p.platform_id = gp.platform_id
JOIN game g
    ON gp.game_id = g.game_id
WHERE up.user_id = (
    SELECT user_id
    FROM app_user
    WHERE username = 'pixelpanda'
)
AND gp.release_date > CURDATE()
AND NOT EXISTS (
    SELECT *
    FROM library_entry le
    WHERE le.user_id = up.user_id
      AND le.game_id = g.game_id
)
ORDER BY gp.release_date, g.title, g.game_id, platform
LIMIT 101 OFFSET 0;


-- ============================================================
-- Feature 3: Personal game library management
-- ============================================================

-- pixelpanda's generated library is empty, so the test adds a game and then updates it.
-- Both steps run in one transaction. ROLLBACK leaves the production database unchanged.
-- Soma is IGDB game 9727.

SELECT 'Feature 3a: pixelpanda adds Soma to backlog' AS test;

START TRANSACTION;

INSERT INTO library_entry (user_id, game_id, status, hours_played)
VALUES (
    (SELECT user_id FROM app_user WHERE username = 'pixelpanda'),
    9727,
    'backlog',
    0
);

SELECT u.username, g.title, le.status, le.hours_played
FROM library_entry le
JOIN app_user u ON le.user_id = u.user_id
JOIN game g ON le.game_id = g.game_id
WHERE u.username = 'pixelpanda';

SELECT 'Feature 3b: pixelpanda updates Soma to playing, 12.5 hours' AS test;

UPDATE library_entry
SET status = 'playing',
    hours_played = 12.5
WHERE user_id = (SELECT user_id FROM app_user WHERE username = 'pixelpanda')
  AND game_id = 9727;

SELECT u.username, g.title, le.status, le.hours_played
FROM library_entry le
JOIN app_user u ON le.user_id = u.user_id
JOIN game g ON le.game_id = g.game_id
WHERE u.username = 'pixelpanda';

ROLLBACK;

SELECT 'Feature 3c: after ROLLBACK, pixelpanda library entries' AS test;

SELECT COUNT(*) AS entries
FROM library_entry le
JOIN app_user u ON le.user_id = u.user_id
WHERE u.username = 'pixelpanda';


-- ============================================================
-- Feature 4: Game ratings and rankings
-- ============================================================

SELECT 'Feature 4: top-rated Shooter games' AS test;

SELECT
    g.title,
    ROUND(AVG(r.score), 2) AS average_rating,
    COUNT(r.score) AS rating_count
FROM game g
JOIN game_genre gg
    ON g.game_id = gg.game_id
JOIN genre ge
    ON gg.genre_id = ge.genre_id
JOIN review r
    ON g.game_id = r.game_id
WHERE ge.name = 'Shooter'
  AND r.score IS NOT NULL
GROUP BY g.game_id, g.title
ORDER BY
    average_rating DESC,
    rating_count DESC,
    g.title
LIMIT 10;