-- Loads data/sample/*.csv into the tables from schema.sql. Run from the repo root:
--   mysql --local-infile=1 -u cs348_app -p cs348 < sql/load_sample.sql
-- Parent tables load before the tables that reference them. \N in a CSV loads as NULL.

LOAD DATA LOCAL INFILE 'data/sample/game.csv' INTO TABLE game
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (game_id, title, steam_app_id, steam_owners_low, steam_owners_high);

LOAD DATA LOCAL INFILE 'data/sample/platform.csv' INTO TABLE platform
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (platform_id, name);

LOAD DATA LOCAL INFILE 'data/sample/genre.csv' INTO TABLE genre
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (genre_id, name);

LOAD DATA LOCAL INFILE 'data/sample/company.csv' INTO TABLE company
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (company_id, name);

LOAD DATA LOCAL INFILE 'data/sample/game_platform.csv' INTO TABLE game_platform
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (game_id, platform_id, release_date);

LOAD DATA LOCAL INFILE 'data/sample/game_genre.csv' INTO TABLE game_genre
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (game_id, genre_id);

LOAD DATA LOCAL INFILE 'data/sample/game_company.csv' INTO TABLE game_company
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (game_id, company_id, is_developer, is_publisher);

LOAD DATA LOCAL INFILE 'data/sample/app_user.csv' INTO TABLE app_user
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (user_id, username, joined_at);

LOAD DATA LOCAL INFILE 'data/sample/user_platform.csv' INTO TABLE user_platform
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (user_id, platform_id);

LOAD DATA LOCAL INFILE 'data/sample/library_entry.csv' INTO TABLE library_entry
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (user_id, game_id, status, hours_played, added_at);

LOAD DATA LOCAL INFILE 'data/sample/review.csv' INTO TABLE review
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES
  (user_id, game_id, score, body, created_at);
