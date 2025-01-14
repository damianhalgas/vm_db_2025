#!/bin/bash

# kopiowanie danych csv
docker cp csv/dane_osobowe.csv postgres-container:/tmp/dane_osobowe.csv
docker cp csv/dane_kontaktowe.csv postgres-container:/tmp/dane_kontaktowe.csv
docker cp csv/dane_firmowe.csv postgres-container:/tmp/dane_firmowe.csv

# Zmienne konfiguracyjne
CONTAINER_NAME="post-conatiner"
DB_NAME="mydatabase"
DB_USER="myuser"
DB_PASSWORD="mypassword"
CSV_DIR="/tmp"  # Katalog w kontenerze, gdzie znajdują się pliki CSV

# Tworzenie tabel w PostgreSQL
echo "Tworzenie tabel w bazie danych..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME <<EOF
CREATE TABLE IF NOT EXISTS dane_osobowe (
    osoba_id UUID PRIMARY KEY,
    imie VARCHAR(50),
    nazwisko VARCHAR(50)
);
CREATE TABLE IF NOT EXISTS dane_kontaktowe (
    osoba_id UUID,
    email VARCHAR(100),
    telefon VARCHAR(20),
    ulica VARCHAR(100),
    numer_domu VARCHAR(10),
    miasto VARCHAR(50),
    kod_pocztowy VARCHAR(10),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
CREATE TABLE IF NOT EXISTS dane_firmowe (
    osoba_id UUID,
    nazwa_firmy VARCHAR(100),
    stanowisko VARCHAR(50),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
EOF

# Import danych z plików CSV
echo "Importowanie danych z plików CSV..."

docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME <<EOF
COPY dane_osobowe(osoba_id, imie, nazwisko) 
FROM '$CSV_DIR/dane_osobowe.csv' 
DELIMITER ',' 
CSV HEADER;

COPY dane_kontaktowe(osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy) 
FROM '$CSV_DIR/dane_kontaktowe.csv' 
DELIMITER ',' 
CSV HEADER;

COPY dane_firmowe(osoba_id, nazwa_firmy, stanowisko) 
FROM '$CSV_DIR/dane_firmowe.csv' 
DELIMITER ',' 
CSV HEADER;
EOF

echo "Import zakończony pomyślnie!"
