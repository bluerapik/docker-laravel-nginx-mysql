-- Init SQL Query for exists Project
CREATE DATABASE IF NOT EXISTS 'laravel';
CREATE USER 'laravel'@'%' IDENTIFIED BY 'laravel';
GRANT ALL ON 'laravel'.* TO 'laravel'@'%';
