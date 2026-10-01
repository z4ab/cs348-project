-- Run once as root: creates the database and the app user.
CREATE DATABASE IF NOT EXISTS cs348;
CREATE USER IF NOT EXISTS 'cs348_app'@'localhost' IDENTIFIED BY 'cs348_pass';
GRANT ALL PRIVILEGES ON cs348.* TO 'cs348_app'@'localhost';
FLUSH PRIVILEGES;
