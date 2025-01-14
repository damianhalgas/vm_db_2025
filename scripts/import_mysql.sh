#!/bin/bash

# Zmienne konfiguracyjne
CONTAINER_NAME="mysql-container"  # Nazwa kontenera MySQL
DB_NAME="mydatabase"              # Nazwa bazy danych
DB_USER="myuser"                  # Użytkownik MySQL
DB_PASSWORD="mypassword"          # Hasło do bazy danych
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

# Tworzenie tabel w MySQL
echo "Tworzenie tabel w bazie danych..."
docker exec -i $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASSWORD -D $DB_NAME <<EOF
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
    numer_domu VARCHAR(10),
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
EOF

# Import danych z plików CSV do tabel
echo "Importowanie danych z plików CSV..."
docker exec -i $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASSWORD -D $DB_NAME <<EOF
LOAD DATA INFILE '$CSV_TARGET_DIR/dane_osobowe.csv'
INTO TABLE dane_osobowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, imie, nazwisko);

LOAD DATA INFILE '$CSV_TARGET_DIR/dane_kontaktowe.csv'
INTO TABLE dane_kontaktowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy);

LOAD DATA INFILE '$CSV_TARGET_DIR/dane_firmowe.csv'
INTO TABLE dane_firmowe
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(osoba_id, nazwa_firmy, stanowisko);
EOF

echo "Import zakończony pomyślnie!"
