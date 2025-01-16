#!/bin/bash

# Zmienne konfiguracyjne
CONTAINER_NAME="post-container"  # Nazwa kontenera PostgreSQL
DB_NAME="mydatabase"               # Nazwa bazy danych
DB_USER="myuser"                   # Użytkownik PostgreSQL
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/utf-8/50K"  # Lokalizacja plików CSV 
CSV_TARGET_DIR="/tmp"                # Lokalizacja plików CSV w kontenerze

# Sprawdzenie, czy pliki CSV istnieją w źródłowej lokalizacji
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# Kopiowanie plików CSV do kontenera
echo "Kopiowanie plików CSV do kontenera PostgreSQL..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$CSV_TARGET_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$CSV_TARGET_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$CSV_TARGET_DIR/dane_firmowe.csv"

# Tworzenie tabel w PostgreSQL
echo "Tworzenie tabel w bazie danych..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME <<EOF
CREATE TABLE IF NOT EXISTS dane_osobowe (
    osoba_id UUID PRIMARY KEY,
    imie VARCHAR(50),
    nazwisko VARCHAR(50),
    data_urodzenia VARCHAR(10)
);
CREATE TABLE IF NOT EXISTS dane_kontaktowe (
    osoba_id UUID,
    email VARCHAR(100),
    telefon VARCHAR(50),
    ulica VARCHAR(100),
    numer_domu VARCHAR(10),
    miasto VARCHAR(50),
    kod_pocztowy VARCHAR(20),
    kraj VARCHAR(100),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
CREATE TABLE IF NOT EXISTS dane_firmowe (
    osoba_id UUID,
    nazwa_firmy VARCHAR(100),
    stanowisko VARCHAR(100),
    branza VARCHAR(100),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
EOF

# Import danych z plików CSV do tabel
echo "Importowanie danych z plików CSV..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME <<EOF
COPY dane_osobowe(osoba_id, imie, nazwisko, data_urodzenia)
FROM '$CSV_TARGET_DIR/dane_osobowe.csv'
DELIMITER ','
CSV HEADER;

COPY dane_kontaktowe(osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy, kraj)
FROM '$CSV_TARGET_DIR/dane_kontaktowe.csv'
DELIMITER ','
CSV HEADER;

COPY dane_firmowe(osoba_id, nazwa_firmy, stanowisko, branza)
FROM '$CSV_TARGET_DIR/dane_firmowe.csv'
DELIMITER ','
CSV HEADER;
EOF

echo "Import zakończony pomyślnie!"
