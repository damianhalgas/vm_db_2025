#!/bin/bash
# Konfiguracja
CONTAINER_NAME="oracle-container"
ORACLE_SID="XE"
ORACLE_PWD="StrongPassword123!"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"
SQL_SCRIPT_DIR="/tmp/sql_scripts"

# Sprawdź, czy pliki CSV istnieją
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# Kopiowanie plików CSV do kontenera
echo "Kopiowanie plików CSV do kontenera Oracle..."
docker exec -i $CONTAINER_NAME bash -c "mkdir -p $SQL_SCRIPT_DIR"
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# Tworzenie tabel i import danych
echo "Tworzenie tabel i importowanie danych..."
docker exec -i $CONTAINER_NAME sqlplus sys/$ORACLE_PWD@//localhost:1521/$ORACLE_SID as sysdba << EOF
-- Tworzenie docelowych tabel
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

-- Tworzenie tabel tymczasowych do importu
CREATE TABLE temp_dane_osobowe (
    osoba_id VARCHAR2(36 CHAR),
    imie VARCHAR2(60 CHAR),
    nazwisko VARCHAR2(60 CHAR),
    data_urodzenia VARCHAR2(10 CHAR)
);

CREATE TABLE temp_dane_kontaktowe (
    osoba_id VARCHAR2(36 CHAR),
    email VARCHAR2(100 CHAR),
    telefon VARCHAR2(60 CHAR),
    ulica VARCHAR2(100 CHAR),
    numer_domu VARCHAR2(60 CHAR),
    miasto VARCHAR2(60 CHAR),
    kod_pocztowy VARCHAR2(60 CHAR),
    kraj VARCHAR2(60 CHAR)
);

CREATE TABLE temp_dane_firmowe (
    osoba_id VARCHAR2(36 CHAR),
    nazwa_firmy VARCHAR2(150 CHAR),
    stanowisko VARCHAR2(255 CHAR),
    branza VARCHAR2(100 CHAR)
);

-- Import do tabel tymczasowych
ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD';

-- Import dane_osobowe
INSERT INTO temp_dane_osobowe
SELECT * FROM (
  SELECT REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 1) AS osoba_id,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 2) AS imie,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 3) AS nazwisko,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 4) AS data_urodzenia
  FROM XMLTABLE('rows/row'
    PASSING XMLTYPE(
      CURSOR(
        SELECT REPLACE(REPLACE(LINE, CHR(13), ''), CHR(10), '') AS line
        FROM (
          SELECT REGEXP_SUBSTR(TRIM(REGEXP_REPLACE(text, '^.+$', '\1', 1, 1, 'm')), '.+', 1, LEVEL) AS LINE
          FROM (SELECT REGEXP_REPLACE(BFILENAME('$SQL_SCRIPT_DIR/dane_osobowe.csv'), '^BOM', '') AS text FROM DUAL)
          CONNECT BY REGEXP_SUBSTR(TRIM(REGEXP_REPLACE(text, '^.+$', '\1', 1, 1, 'm')), '.+', 1, LEVEL) IS NOT NULL
        )
      )
    )
  )
) WHERE osoba_id != 'osoba_id';

-- Import dane_kontaktowe
INSERT INTO temp_dane_kontaktowe
SELECT * FROM (
  SELECT REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 1) AS osoba_id,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 2) AS email,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 3) AS telefon,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 4) AS ulica,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 5) AS numer_domu,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 6) AS miasto,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 7) AS kod_pocztowy,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 8) AS kraj
  FROM XMLTABLE('rows/row'
    PASSING XMLTYPE(
      CURSOR(
        SELECT REPLACE(REPLACE(LINE, CHR(13), ''), CHR(10), '') AS line
        FROM (
          SELECT REGEXP_SUBSTR(TRIM(REGEXP_REPLACE(text, '^.+$', '\1', 1, 1, 'm')), '.+', 1, LEVEL) AS LINE
          FROM (SELECT REGEXP_REPLACE(BFILENAME('$SQL_SCRIPT_DIR/dane_kontaktowe.csv'), '^BOM', '') AS text FROM DUAL)
          CONNECT BY REGEXP_SUBSTR(TRIM(REGEXP_REPLACE(text, '^.+$', '\1', 1, 1, 'm')), '.+', 1, LEVEL) IS NOT NULL
        )
      )
    )
  )
) WHERE osoba_id != 'osoba_id';

-- Import dane_firmowe
INSERT INTO temp_dane_firmowe
SELECT * FROM (
  SELECT REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 1) AS osoba_id,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 2) AS nazwa_firmy,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 3) AS stanowisko,
         REGEXP_SUBSTR(COLUMN_VALUE, '[^,]+', 1, 4) AS branza
  FROM XMLTABLE('rows/row'
    PASSING XMLTYPE(
      CURSOR(
        SELECT REPLACE(REPLACE(LINE, CHR(13), ''), CHR(10), '') AS line
        FROM (
          SELECT REGEXP_SUBSTR(TRIM(REGEXP_REPLACE(text, '^.+$', '\1', 1, 1, 'm')), '.+', 1, LEVEL) AS LINE
          FROM (SELECT REGEXP_REPLACE(BFILENAME('$SQL_SCRIPT_DIR/dane_firmowe.csv'), '^BOM', '') AS text FROM DUAL)
          CONNECT BY REGEXP_SUBSTR(TRIM(REGEXP_REPLACE(text, '^.+$', '\1', 1, 1, 'm')), '.+', 1, LEVEL) IS NOT NULL
        )
      )
    )
  )
) WHERE osoba_id != 'osoba_id';

-- Przeniesienie danych do tabel docelowych
INSERT INTO dane_osobowe
SELECT osoba_id, imie, nazwisko, TO_DATE(data_urodzenia, 'YYYY-MM-DD')
FROM temp_dane_osobowe;

INSERT INTO dane_kontaktowe
SELECT * FROM temp_dane_kontaktowe;

INSERT INTO dane_firmowe
SELECT * FROM temp_dane_firmowe;

-- Usunięcie tabel tymczasowych
DROP TABLE temp_dane_osobowe;
DROP TABLE temp_dane_kontaktowe;
DROP TABLE temp_dane_firmowe;

-- Sprawdzenie liczby zaimportowanych rekordów
SELECT 'dane_osobowe' as tabela, COUNT(*) as liczba_rekordow FROM dane_osobowe;
SELECT 'dane_kontaktowe' as tabela, COUNT(*) as liczba_rekordow FROM dane_kontaktowe;
SELECT 'dane_firmowe' as tabela, COUNT(*) as liczba_rekordow FROM dane_firmowe;

COMMIT;
EXIT;
EOF

echo "Import zakończony"