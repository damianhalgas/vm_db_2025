#!/bin/bash

# Zmienne konfiguracyjne
CONTAINER_NAME="mssql-container"
DB_NAME="MyDatabase"
SA_PASSWORD="StrongPassword123!"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"  # Lokalizacja plików CSV
SQL_SCRIPT_DIR="/tmp/sql_scripts"  # Skrypty SQL w kontenerze

# Sprawdzenie, czy pliki CSV istnieją w źródłowej lokalizacji
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# Uruchomienie kontenera z MSSQL
echo "Uruchamianie kontenera MSSQL..."
docker-compose up -d

# Czekanie na pełne uruchomienie MSSQL
echo "Czekanie na uruchomienie MSSQL..."
sleep 15  # Możesz zwiększyć czas, jeśli MSSQL potrzebuje więcej na start

# Tworzenie katalogu na skrypty SQL w kontenerze
docker exec -i $CONTAINER_NAME mkdir -p $SQL_SCRIPT_DIR

# Tworzenie bazy danych i tabel
echo "Tworzenie bazy danych i tabel..."
docker exec -i $CONTAINER_NAME /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -C -Q "
CREATE DATABASE [$DB_NAME];
USE [$DB_NAME];
CREATE TABLE dane_osobowe (
    osoba_id UNIQUEIDENTIFIER PRIMARY KEY,
    imie NVARCHAR(60),
    nazwisko NVARCHAR(60),
    data_urodzenia DATE
);
CREATE TABLE dane_kontaktowe (
    kontakt_id INT IDENTITY PRIMARY KEY,
    osoba_id UNIQUEIDENTIFIER,
    email NVARCHAR(100),
    telefon NVARCHAR(60),
    ulica NVARCHAR(100),
    numer_domu NVARCHAR(60),
    miasto NVARCHAR(60),
    kod_pocztowy NVARCHAR(60),
    kraj NVARCHAR(60),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
CREATE TABLE dane_firmowe (
    firma_id INT IDENTITY PRIMARY KEY,
    osoba_id UNIQUEIDENTIFIER,
    nazwa_firmy NVARCHAR(150),
    stanowisko NVARCHAR(255),
    branza NVARCHAR(100),
    FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);
"

# Kopiowanie plików CSV do kontenera
echo "Kopiowanie plików CSV do kontenera MSSQL..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# Import danych z plików CSV
echo "Importowanie danych z plików CSV..."
docker exec -i $CONTAINER_NAME /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d $DB_NAME -C -Q "
BULK INSERT dane_osobowe
FROM '$SQL_SCRIPT_DIR/dane_osobowe.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);
BULK INSERT dane_kontaktowe
FROM '$SQL_SCRIPT_DIR/dane_kontaktowe.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);
BULK INSERT dane_firmowe
FROM '$SQL_SCRIPT_DIR/dane_firmowe.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);
"

echo "Import zakończony pomyślnie!"
