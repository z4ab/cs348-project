-- Creates and inits (or resets) the sample tables.
DROP TABLE IF EXISTS student;

CREATE TABLE student (
  uid   DECIMAL(3, 0) NOT NULL PRIMARY KEY,
  name  VARCHAR(30)   NOT NULL,
  score DECIMAL(3, 2) CHECK (score BETWEEN 0 AND 1)
);

INSERT INTO student (uid, name, score) VALUES
  (1, 'alice', 0.10),
  (2, 'bob',   0.40),
  (3, 'carol', 0.85),
  (4, 'dave',  0.62),
  (5, 'erin',  NULL);
