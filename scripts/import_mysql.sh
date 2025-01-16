#!/bin/bash

# Zmienne konfiguracyjne
CONTAINER_NAME="mysql-container"  # Nazwa kontenera MySQL
DB_NAME="mydatabase"              # Nazwa bazy danych
DB_ROOT_USER="root"               # Użytkownik root
DB_ROOT_PASSWORD="rootpassword"   # Hasło użytkownika root
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/utf-8/50K"  # Lokalizacja plików CSV 
CSV_TARGET_DIR="/tmp"             # Lokalizacja plików CSV w kontenerze

# Sprawdzenie, czy pliki CSV istnieją w źródłowej lokalizacji
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# Kopiowanie plików CSV do kontenera
echo "Kopiowanie plików CSV do kontenera MySQL..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$CSV_TARGET_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$CSV_TARGET_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$CSV_TARGET_DIR/dane_firmowe.csv"

# Tworzenie tabel w MySQL
echo "Tworzenie tabel w bazie danych..."
docker exec -i $CONTAINER_NAME mysql -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
USE $DB_NAME;

CREATE TABLE IF NOT EXISTS dane_osobowe (
    osoba_id CHAR(36) PRIMARY KEY,  -- UUID jako klucz główny
    imie VARCHAR(60),
    nazwisko VARCHAR(60),
    data_urodzenia DATE  -- Dodano pole data_urodzenia
);

CREATE TABLE IF NOT EXISTS dane_kontaktowe (
    osoba_id CHAR(36),  -- UUID jako klucz obcy
    email VARCHAR(100),
    telefon VARCHAR(60),
    ulica VARCHAR(100),
    numer_domu VARCHAR(60),
    miasto VARCHAR(60),
    kod_pocztowy VARCHAR(60),
    kraj VARCHAR(60),  -- Dodano pole kraj
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

CREATE TABLE IF NOT EXISTS dane_firmowe (
    osoba_id CHAR(36),  -- UUID jako klucz obcy
    nazwa_firmy VARCHAR(150),
    stanowisko VARCHAR(255),
    branza VARCHAR(100),  -- Dodano pole branza
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
EOF

# Import danych z plików CSV do tabel
echo "Importowanie danych z plików CSV..."
docker exec -i $CONTAINER_NAME mysql -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD <<EOF
USE $DB_NAME;

LOAD DATA INFILE '$CSV_TARGET_DIR/dane_osobowe.csv'
INTO TABLE dane_osobowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, imie, nazwisko, data_urodzenia);

LOAD DATA INFILE '$CSV_TARGET_DIR/dane_kontaktowe.csv'
INTO TABLE dane_kontaktowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy, kraj);

LOAD DATA INFILE '$CSV_TARGET_DIR/dane_firmowe.csv'
INTO TABLE dane_firmowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, nazwa_firmy, stanowisko, branza);
EOF

echo "Import zakończony pomyślnie!"
