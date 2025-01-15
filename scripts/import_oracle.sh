#!/bin/bash
# -----------------------------------------------------------
# Skrypt ładowania danych z plików CSV do bazy Oracle (w kontenerze Docker)
# za pomocą SQL*Loader (poprawny i prostszy sposób).
# -----------------------------------------------------------

# ----- KONFIGURACJA -----
CONTAINER_NAME="oracle-container"
ORACLE_SID="XE"
ORACLE_PWD="oracle"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"
SQL_SCRIPT_DIR="/tmp/sql_scripts"

# -- 1. Sprawdź, czy pliki CSV istnieją --
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# -- 2. (Opcjonalnie) usuń BOM z plików CSV (jeśli występuje) --
# sed -i '1s/^\xef\xbb\xbf//' "$CSV_SOURCE_DIR/dane_osobowe.csv"
# sed -i '1s/^\xef\xbb\xbf//' "$CSV_SOURCE_DIR/dane_kontaktowe.csv"
# sed -i '1s/^\xef\xbb\xbf//' "$CSV_SOURCE_DIR/dane_firmowe.csv"

# -- 3. Przygotuj kontrolne pliki .ctl dla SQL*Loadera --
# (W każdym deklarujemy, że dane są w UTF-8 oraz że rozdzielane są przecinkami)

cat > dane_osobowe.ctl << EOF
LOAD DATA
CHARACTERSET UTF8
INFILE '$SQL_SCRIPT_DIR/dane_osobowe.csv'
INTO TABLE dane_osobowe
APPEND
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  osoba_id       CHAR(36),
  imie           CHAR(60),
  nazwisko       CHAR(60),
  data_urodzenia CHAR(10) 
)
EOF

cat > dane_kontaktowe.ctl << EOF
LOAD DATA
CHARACTERSET UTF8
INFILE '$SQL_SCRIPT_DIR/dane_kontaktowe.csv'
INTO TABLE dane_kontaktowe
APPEND
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  osoba_id      CHAR(36),
  email         CHAR(100),
  telefon       CHAR(60),
  ulica         CHAR(100),
  numer_domu    CHAR(60),
  miasto        CHAR(60),
  kod_pocztowy  CHAR(60),
  kraj          CHAR(60)
)
EOF

cat > dane_firmowe.ctl << EOF
LOAD DATA
CHARACTERSET UTF8
INFILE '$SQL_SCRIPT_DIR/dane_firmowe.csv'
INTO TABLE dane_firmowe
APPEND
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  osoba_id     CHAR(36),
  nazwa_firmy  CHAR(150),
  stanowisko   CHAR(255),
  branza       CHAR(100)
)
EOF

# -- 4. Kopiowanie plików kontrolnych i CSV do kontenera --
echo "Kopiowanie plików .ctl i .csv do kontenera..."
docker exec -i $CONTAINER_NAME bash -c "mkdir -p $SQL_SCRIPT_DIR"

docker cp dane_osobowe.ctl    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.ctl"
docker cp dane_kontaktowe.ctl $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.ctl"
docker cp dane_firmowe.ctl    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.ctl"

docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv"   $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv"    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# -- 5. Tworzenie tabel w bazie (lub wyczyszczenie, jeśli istnieją) --
echo "Tworzenie tabel w bazie..."
docker exec -i $CONTAINER_NAME sqlplus sys/$ORACLE_PWD@//localhost:1521/$ORACLE_SID as sysdba <<EOF
WHENEVER SQLERROR CONTINUE

-- Usuwamy tabele, jeśli istnieją (unikamy błędów przez CONTINUE)
DROP TABLE dane_firmowe CASCADE CONSTRAINTS;
DROP TABLE dane_kontaktowe CASCADE CONSTRAINTS;
DROP TABLE dane_osobowe CASCADE CONSTRAINTS;

CREATE TABLE dane_osobowe (
    osoba_id VARCHAR2(36 CHAR) PRIMARY KEY,
    imie VARCHAR2(60 CHAR),
    nazwisko VARCHAR2(60 CHAR),
    data_urodzenia DATE
);

CREATE TABLE dane_kontaktowe (
    osoba_id VARCHAR2(36 CHAR),
    email VARCHAR2(100 CHAR),
    telefon VARCHAR2(60 CHAR),
    ulica VARCHAR2(100 CHAR),
    numer_domu VARCHAR2(60 CHAR),
    miasto VARCHAR2(60 CHAR),
    kod_pocztowy VARCHAR2(60 CHAR),
    kraj VARCHAR2(60 CHAR),
    CONSTRAINT fk_dane_kontaktowe_osoba FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

CREATE TABLE dane_firmowe (
    osoba_id VARCHAR2(36 CHAR),
    nazwa_firmy VARCHAR2(150 CHAR),
    stanowisko VARCHAR2(255 CHAR),
    branza VARCHAR2(100 CHAR),
    CONSTRAINT fk_dane_firmowe_osoba FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

EXIT;
EOF

# -- 6. Uruchom SQL*Loader i załaduj dane --
# Klucz: "sys/haslo@... AS SYSDBA" musi być w cudzysłowach
echo "Ładowanie danych do tabel..."
docker exec -i $CONTAINER_NAME bash -c "
  cd $SQL_SCRIPT_DIR
  sqlldr \"sys/$ORACLE_PWD@//localhost:1521/$ORACLE_SID AS SYSDBA\" control=dane_osobowe.ctl
  sqlldr \"sys/$ORACLE_PWD@//localhost:1521/$ORACLE_SID AS SYSDBA\" control=dane_kontaktowe.ctl
  sqlldr \"sys/$ORACLE_PWD@//localhost:1521/$ORACLE_SID AS SYSDBA\" control=dane_firmowe.ctl
"

# -- 7. Sprawdź wyniki --
echo "Sprawdzenie liczby zaimportowanych rekordów..."
docker exec -i $CONTAINER_NAME sqlplus sys/$ORACLE_PWD@//localhost:1521/$ORACLE_SID as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

COLUMN tabela        FORMAT A20
COLUMN liczba_rekordow FORMAT 9999999

SELECT 'dane_osobowe'   AS tabela, COUNT(*) AS liczba_rekordow FROM dane_osobowe;
SELECT 'dane_kontaktowe' AS tabela, COUNT(*) AS liczba_rekordow FROM dane_kontaktowe;
SELECT 'dane_firmowe'   AS tabela, COUNT(*) AS liczba_rekordow FROM dane_firmowe;

EXIT;
EOF

echo "Import zakończony."
