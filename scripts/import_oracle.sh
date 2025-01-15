#!/bin/bash
# Configuration variables
CONTAINER_NAME="oracle-container"
ORACLE_SID="ORCL"
ORACLE_PDB="PDB1"
ORACLE_PWD="StrongPassword123!"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"
SQL_SCRIPT_DIR="/tmp/sql_scripts"

# Check if CSV files exist
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Error: One or more CSV files don't exist in $CSV_SOURCE_DIR."
  exit 1
fi

# Start Oracle container
echo "Starting Oracle container..."
docker-compose up -d $CONTAINER_NAME

# Wait for Oracle to start
echo "Waiting for Oracle to start..."
sleep 120  # Oracle potrzebuje więcej czasu na inicjalizację

# Create directory for SQL scripts in container
docker exec -i $CONTAINER_NAME mkdir -p $SQL_SCRIPT_DIR

# Copy CSV files to container
echo "Copying CSV files to Oracle container..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# Create tables and import data
echo "Creating tables and importing data..."
docker exec -i $CONTAINER_NAME bash -c "
sqlplus sys/$ORACLE_PWD@//$ORACLE_SID as sysdba <<EOF
CREATE USER myuser IDENTIFIED BY $ORACLE_PWD;
GRANT CONNECT, RESOURCE TO myuser;

ALTER SESSION SET CONTAINER=$ORACLE_PDB;

-- Create tables
CREATE TABLE myuser.dane_osobowe (
    osoba_id VARCHAR2(36 CHAR) PRIMARY KEY,
    imie VARCHAR2(60 CHAR),
    nazwisko VARCHAR2(60 CHAR),
    data_urodzenia DATE
);

CREATE TABLE myuser.dane_kontaktowe (
    osoba_id VARCHAR2(36 CHAR),
    email VARCHAR2(100 CHAR),
    telefon VARCHAR2(60 CHAR),
    ulica VARCHAR2(100 CHAR),
    numer_domu VARCHAR2(60 CHAR),
    miasto VARCHAR2(60 CHAR),
    kod_pocztowy VARCHAR2(60 CHAR),
    kraj VARCHAR2(60 CHAR),
    CONSTRAINT fk_dane_kontaktowe_osoba FOREIGN KEY (osoba_id) REFERENCES myuser.dane_osobowe(osoba_id)
);

CREATE TABLE myuser.dane_firmowe (
    osoba_id VARCHAR2(36 CHAR),
    nazwa_firmy VARCHAR2(150 CHAR),
    stanowisko VARCHAR2(255 CHAR),
    branza VARCHAR2(100 CHAR),
    CONSTRAINT fk_dane_firmowe_osoba FOREIGN KEY (osoba_id) REFERENCES myuser.dane_osobowe(osoba_id)
);

-- Import data from CSV
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE myuser.dane_osobowe';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE myuser.dane_kontaktowe';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE myuser.dane_firmowe';
END;
/

-- Load data
LOAD DATA INFILE '$SQL_SCRIPT_DIR/dane_osobowe.csv'
INTO TABLE myuser.dane_osobowe
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
(osoba_id, imie, nazwisko, data_urodzenia);

LOAD DATA INFILE '$SQL_SCRIPT_DIR/dane_kontaktowe.csv'
INTO TABLE myuser.dane_kontaktowe
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
(osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy, kraj);

LOAD DATA INFILE '$SQL_SCRIPT_DIR/dane_firmowe.csv'
INTO TABLE myuser.dane_firmowe
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
(osoba_id, nazwa_firmy, stanowisko, branza);

COMMIT;
EOF
"

echo "Import completed successfully!"
