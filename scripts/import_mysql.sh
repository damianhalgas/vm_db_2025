#!/bin/bash

# Zmienne konfiguracyjne
CONTAINER_NAME="mysql-container"  # Nazwa kontenera MySQL
DB_NAME="mydatabase"              # Nazwa bazy danych
DB_USER="root"                    # Użytkownik MySQL
DB_PASSWORD="rootpassword"        # Hasło użytkownika MySQL
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"  # Lokalizacja plików CSV
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

# Importowanie danych do MySQL z obsługą konfliktów
echo "Importowanie danych z obsługą konfliktów do tabel MySQL..."
docker exec -i $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASSWORD -D $DB_NAME <<EOF
-- Tworzenie tabel, jeśli jeszcze nie istnieją
CREATE TABLE IF NOT EXISTS dane_osobowe (
    osoba_id CHAR(36) PRIMARY KEY,
    imie VARCHAR(50),
    nazwisko VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dane_kontaktowe (
    osoba_id CHAR(36),
    email VARCHAR(100),
    telefon VARCHAR(50),
    ulica VARCHAR(100),
    numer_domu VARCHAR(20),
    miasto VARCHAR(50),
    kod_pocztowy VARCHAR(20),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

CREATE TABLE IF NOT EXISTS dane_firmowe (
    osoba_id CHAR(36),
    nazwa_firmy VARCHAR(100),
    stanowisko VARCHAR(100),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

-- Import danych do tabeli dane_osobowe z ignorowaniem duplikatów
LOAD DATA INFILE '$CSV_TARGET_DIR/dane_osobowe.csv'
IGNORE INTO TABLE dane_osobowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, imie, nazwisko);

-- Import danych do tabeli dane_kontaktowe z ignorowaniem duplikatów
LOAD DATA INFILE '$CSV_TARGET_DIR/dane_kontaktowe.csv'
IGNORE INTO TABLE dane_kontaktowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy);

-- Import danych do tabeli dane_firmowe z nadpisywaniem istniejących rekordów
LOAD DATA INFILE '$CSV_TARGET_DIR/dane_firmowe.csv'
REPLACE INTO TABLE dane_firmowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, nazwa_firmy, stanowisko);
EOF

echo "Import zakończony pomyślnie!"
