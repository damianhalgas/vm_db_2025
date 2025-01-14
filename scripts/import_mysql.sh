#!/bin/bash

CONTAINER_NAME="mysql-container"
DB_NAME="mydatabase"
DB_ROOT_USER="root"
DB_ROOT_PASSWORD="rootpassword"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"
CSV_TARGET_DIR="/tmp"

# Tworzenie tabel z relacjami
docker exec -i $CONTAINER_NAME mysql -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
USE $DB_NAME;

CREATE TABLE IF NOT EXISTS dane_osobowe (
    osoba_id INT AUTO_INCREMENT PRIMARY KEY,
    imie VARCHAR(60),
    nazwisko VARCHAR(60)
);

CREATE TABLE IF NOT EXISTS dane_kontaktowe (
    osoba_id INT PRIMARY KEY,
    email VARCHAR(100),
    telefon VARCHAR(60),
    ulica VARCHAR(100),
    numer_domu VARCHAR(60),
    miasto VARCHAR(60),
    kod_pocztowy VARCHAR(60),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

CREATE TABLE IF NOT EXISTS dane_firmowe (
    osoba_id INT PRIMARY KEY,
    nazwa_firmy VARCHAR(150),
    stanowisko VARCHAR(255),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

-- Wyszukiwanie osoby i jej danych w innych tabelach
DELIMITER $$
CREATE PROCEDURE find_person (IN first_name VARCHAR(60), IN last_name VARCHAR(60))
BEGIN
    SELECT o.osoba_id, o.imie, o.nazwisko, 
           k.email, k.telefon, 
           f.nazwa_firmy, f.stanowisko
    FROM dane_osobowe o
    LEFT JOIN dane_kontaktowe k ON o.osoba_id = k.osoba_id
    LEFT JOIN dane_firmowe f ON o.osoba_id = f.osoba_id
    WHERE o.imie = first_name AND o.nazwisko = last_name;
END$$
DELIMITER ;
EOF
