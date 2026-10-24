-- Creates (or resets) the game tracker tables. Child tables are dropped first.
DROP TABLE IF EXISTS review;
DROP TABLE IF EXISTS library_entry;
DROP TABLE IF EXISTS user_platform;
DROP TABLE IF EXISTS app_user;
DROP TABLE IF EXISTS game_company;
DROP TABLE IF EXISTS game_genre;
DROP TABLE IF EXISTS game_platform;
DROP TABLE IF EXISTS company;
DROP TABLE IF EXISTS genre;
DROP TABLE IF EXISTS platform;
DROP TABLE IF EXISTS game;

-- IGDB data, plus SteamSpy popularity for games sold on Steam.
CREATE TABLE game (
  game_id           INT          NOT NULL PRIMARY KEY,  -- IGDB game id
  title             VARCHAR(255) NOT NULL,
  steam_app_id      INT          UNIQUE,                -- NULL if not on Steam
  steam_owners_low  INT,                                -- SteamSpy owner range, NULL if not on Steam
  steam_owners_high INT,
  CHECK (steam_owners_low <= steam_owners_high),
  CHECK ((steam_owners_low IS NULL) = (steam_owners_high IS NULL))
);

CREATE TABLE platform (
  platform_id INT          NOT NULL PRIMARY KEY,  -- IGDB platform id
  name        VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE genre (
  genre_id INT          NOT NULL PRIMARY KEY,  -- IGDB genre id
  name     VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE company (
  company_id INT          NOT NULL PRIMARY KEY,  -- IGDB company id
  name       VARCHAR(255) NOT NULL
);

-- One row per platform a game is on. release_date is the earliest date IGDB lists
-- for that platform, NULL if IGDB has none.
CREATE TABLE game_platform (
  game_id      INT  NOT NULL,
  platform_id  INT  NOT NULL,
  release_date DATE,
  PRIMARY KEY (game_id, platform_id),
  FOREIGN KEY (game_id) REFERENCES game (game_id),
  FOREIGN KEY (platform_id) REFERENCES platform (platform_id)
);

CREATE TABLE game_genre (
  game_id  INT NOT NULL,
  genre_id INT NOT NULL,
  PRIMARY KEY (game_id, genre_id),
  FOREIGN KEY (game_id) REFERENCES game (game_id),
  FOREIGN KEY (genre_id) REFERENCES genre (genre_id)
);

CREATE TABLE game_company (
  game_id      INT     NOT NULL,
  company_id   INT     NOT NULL,
  is_developer BOOLEAN NOT NULL,
  is_publisher BOOLEAN NOT NULL,
  PRIMARY KEY (game_id, company_id),
  FOREIGN KEY (game_id) REFERENCES game (game_id),
  FOREIGN KEY (company_id) REFERENCES company (company_id),
  CHECK (is_developer OR is_publisher)
);

CREATE TABLE app_user (
  user_id  INT         NOT NULL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE
);

-- Platforms a user owns, used to filter the release calendar.
CREATE TABLE user_platform (
  user_id     INT NOT NULL,
  platform_id INT NOT NULL,
  PRIMARY KEY (user_id, platform_id),
  FOREIGN KEY (user_id) REFERENCES app_user (user_id),
  FOREIGN KEY (platform_id) REFERENCES platform (platform_id)
);

CREATE TABLE library_entry (
  user_id      INT          NOT NULL,
  game_id      INT          NOT NULL,
  status       ENUM('backlog', 'playing', 'completed') NOT NULL,
  hours_played DECIMAL(7,1) NOT NULL DEFAULT 0,
  added_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, game_id),
  FOREIGN KEY (user_id) REFERENCES app_user (user_id),
  FOREIGN KEY (game_id) REFERENCES game (game_id),
  CHECK (hours_played >= 0)
);

-- A review has a score, a written comment, or both.
CREATE TABLE review (
  user_id    INT      NOT NULL,
  game_id    INT      NOT NULL,
  score      TINYINT,
  body       VARCHAR(2000),
  created_at DATETIME NOT NULL,
  PRIMARY KEY (user_id, game_id),
  FOREIGN KEY (user_id) REFERENCES app_user (user_id),
  FOREIGN KEY (game_id) REFERENCES game (game_id),
  CHECK (score BETWEEN 1 AND 10),
  CHECK (score IS NOT NULL OR body IS NOT NULL)
);
