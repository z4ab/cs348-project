-- Tests each Milestone 1 schema assumption (R5a) against the production database (R5d).
-- Each query counts the rows that break the assumption. 0 means it holds.
-- Load sql/schema.sql and sql/load_production.sql before running this file.

SELECT 'A1: no two games share a Steam app id' AS assumption;
SELECT COUNT(*) AS violations
FROM (SELECT steam_app_id FROM game WHERE steam_app_id IS NOT NULL
      GROUP BY steam_app_id HAVING COUNT(*) > 1) d;

SELECT 'A2: a game with a Steam app id has an owner range' AS assumption;
SELECT COUNT(*) AS games_with_steam_id,
       SUM(steam_owners_low IS NULL) AS violations
FROM game WHERE steam_app_id IS NOT NULL;

SELECT 'A3: owner lower bound does not exceed the upper bound' AS assumption;
SELECT COUNT(*) AS violations FROM game WHERE steam_owners_low > steam_owners_high;

SELECT 'A4: every username is unique' AS assumption;
SELECT COUNT(*) - COUNT(DISTINCT username) AS violations FROM app_user;

SELECT 'A5: every game has at least one platform release' AS assumption;
SELECT COUNT(*) AS violations
FROM game g WHERE NOT EXISTS (SELECT * FROM game_platform gp WHERE gp.game_id = g.game_id);

SELECT 'A6: every game has at least one genre' AS assumption;
SELECT COUNT(*) AS violations
FROM game g WHERE NOT EXISTS (SELECT * FROM game_genre gg WHERE gg.game_id = g.game_id);

SELECT 'A7: every game has at least one developer' AS assumption;
SELECT COUNT(*) AS violations
FROM game g WHERE NOT EXISTS (SELECT * FROM game_company gc
                              WHERE gc.game_id = g.game_id AND gc.is_developer);

SELECT 'A8: every game has at least one publisher' AS assumption;
SELECT COUNT(*) AS violations
FROM game g WHERE NOT EXISTS (SELECT * FROM game_company gc
                              WHERE gc.game_id = g.game_id AND gc.is_publisher);

SELECT 'A9: a release date may be unknown (allowed, counted for reference)' AS assumption;
SELECT COUNT(*) AS releases, SUM(release_date IS NULL) AS undated FROM game_platform;

SELECT 'A10: a company can develop and publish the same game (allowed, counted for reference)' AS assumption;
SELECT COUNT(*) AS credits FROM game_company WHERE is_developer AND is_publisher;

SELECT 'A11: platforms, genres and companies may have no games (allowed, counted for reference)' AS assumption;
SELECT (SELECT COUNT(*) FROM platform p
        WHERE NOT EXISTS (SELECT * FROM game_platform gp WHERE gp.platform_id = p.platform_id)) AS platforms,
       (SELECT COUNT(*) FROM genre ge
        WHERE NOT EXISTS (SELECT * FROM game_genre gg WHERE gg.genre_id = ge.genre_id)) AS genres,
       (SELECT COUNT(*) FROM company c
        WHERE NOT EXISTS (SELECT * FROM game_company gc WHERE gc.company_id = c.company_id)) AS companies;

SELECT 'A12: a game has at most one release record per platform (primary key)' AS assumption;
SELECT COUNT(*) AS violations
FROM (SELECT game_id, platform_id FROM game_platform
      GROUP BY game_id, platform_id HAVING COUNT(*) > 1) d;
