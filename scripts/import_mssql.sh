#!/bin/bash
# Configuration variables
CONTAINER_NAME="mssql-container"
DB_NAME="mydatabase"
SA_PASSWORD="StrongPassword123!"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/utf-8/20K"
SQL_SCRIPT_DIR="/tmp/sql_scripts"

# Check if CSV files exist
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Error: One or more CSV files don't exist in $CSV_SOURCE_DIR."
  exit 1
fi

# Start MSSQL container
echo "Starting MSSQL container..."
docker-compose up -d $CONTAINER_NAME

# Wait for MSSQL to start
echo "Waiting for MSSQL to start..."
sleep 15

# Create directory for SQL scripts in container
docker exec -i $CONTAINER_NAME mkdir -p $SQL_SCRIPT_DIR

# Create database and tables
echo "Creating database and tables..."
docker exec -i $CONTAINER_NAME /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -C -Q "
IF DB_ID('$DB_NAME') IS NULL
    CREATE DATABASE [$DB_NAME];
USE [$DB_NAME];

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='dane_osobowe' AND xtype='U')
BEGIN
    CREATE TABLE dane_osobowe (
        osoba_id UNIQUEIDENTIFIER PRIMARY KEY,
        imie VARCHAR(60),
        nazwisko VARCHAR(60),
        data_urodzenia VARCHAR(60)
    );
END;

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='dane_kontaktowe' AND xtype='U')
BEGIN
    CREATE TABLE dane_kontaktowe (
        osoba_id UNIQUEIDENTIFIER,
        email VARCHAR(100),
        telefon VARCHAR(60),
        ulica VARCHAR(100),
        numer_domu VARCHAR(60),
        miasto VARCHAR(60),
        kod_pocztowy VARCHAR(60),
        kraj VARCHAR(60),
        FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
    );
END;

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='dane_firmowe' AND xtype='U')
BEGIN
    CREATE TABLE dane_firmowe (
        osoba_id UNIQUEIDENTIFIER,
        nazwa_firmy VARCHAR(150),
        stanowisko VARCHAR(255),
        branza VARCHAR(100),
        FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
    );
END;
"

# Copy CSV files to container
echo "Copying CSV files to MSSQL container..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# Import data from CSV files
echo "Importing data from CSV files..."
docker exec -i $CONTAINER_NAME /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d $DB_NAME -C -Q "
-- Disable foreign key constraints temporarily
ALTER TABLE dane_kontaktowe NOCHECK CONSTRAINT ALL;
ALTER TABLE dane_firmowe NOCHECK CONSTRAINT ALL;

-- Import data
BULK INSERT dane_osobowe
FROM '$SQL_SCRIPT_DIR/dane_osobowe.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK
);

BULK INSERT dane_kontaktowe
FROM '$SQL_SCRIPT_DIR/dane_kontaktowe.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK
);

BULK INSERT dane_firmowe
FROM '$SQL_SCRIPT_DIR/dane_firmowe.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK
);

-- Re-enable foreign key constraints
ALTER TABLE dane_kontaktowe WITH CHECK CHECK CONSTRAINT ALL;
ALTER TABLE dane_firmowe WITH CHECK CHECK CONSTRAINT ALL;

-- Verify record counts
SELECT 'dane_osobowe' AS tabela, COUNT(*) AS liczba_rekordow FROM dane_osobowe
UNION ALL
SELECT 'dane_kontaktowe', COUNT(*) FROM dane_kontaktowe
UNION ALL
SELECT 'dane_firmowe', COUNT(*) FROM dane_firmowe;
"

echo "Import completed successfully!"