#!/bin/bash
# -----------------------------------------------------------------
# Skrypt ładowania danych z plików CSV do bazy Oracle w kontenerze
# przy użyciu SQL*Loader. Sprawdzony w Oracle 11g/12c/21c i Docker.
# -----------------------------------------------------------------

# 1. KONFIGURACJA
CONTAINER_NAME="oracle-container"     # nazwa uruchomionego kontenera
ORACLE_SID="XE"
ORACLE_PWD="oracle"                   # hasło do SYS
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"
SQL_SCRIPT_DIR="/tmp/sql_scripts"
LOG_DIR="/tmp/sql_loader_logs"

# Funkcja do usuwania BOM z plików CSV (jeśli pliki mają BOM)
remove_bom() {
  local file=$1
  sed -i '1s/^\xEF\xBB\xBF//' "$file"
}

# 2. SPRAWDZENIE PLIKÓW CSV
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# 3. (OPCJONALNIE) USUNIĘCIE BOM
echo "Usuwanie BOM z plików CSV (o ile występuje)..."
remove_bom "$CSV_SOURCE_DIR/dane_osobowe.csv"
remove_bom "$CSV_SOURCE_DIR/dane_kontaktowe.csv"
remove_bom "$CSV_SOURCE_DIR/dane_firmowe.csv"

# 4. TWORZENIE PLIKÓW .CTL
echo "Tworzenie plików kontrolnych SQL*Loadera..."

cat > dane_osobowe.ctl <<EOF
LOAD DATA
CHARACTERSET UTF8
INFILE '$SQL_SCRIPT_DIR/dane_osobowe.csv'
INTO TABLE dane_osobowe
APPEND
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  osoba_id        CHAR(36),
  imie            CHAR(60),
  nazwisko        CHAR(60),
  -- jeżeli CSV ma daty w formacie YYYY-MM-DD
  data_urodzenia  CHAR(10) "YYYY-MM-DD"
)
EOF

cat > dane_kontaktowe.ctl <<EOF
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

cat > dane_firmowe.ctl <<EOF
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

# 5. TWORZENIE KATALOGÓW NA HOŚCIE I W KONTENERZE
mkdir -p "$LOG_DIR"
docker exec -i $CONTAINER_NAME bash -c "mkdir -p $SQL_SCRIPT_DIR"

# 6. KOPIOWANIE PLIKÓW DO KONTENERA
echo "Kopiowanie plików .ctl i .csv do kontenera..."

docker cp dane_osobowe.ctl    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.ctl"
docker cp dane_kontaktowe.ctl $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.ctl"
docker cp dane_firmowe.ctl    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.ctl"

docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv"    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv"    $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# 7. TWORZENIE TABEL W BAZIE
echo "Tworzenie tabel w bazie Oracle..."

docker exec -i $CONTAINER_NAME bash -c "
sqlplus sys/$ORACLE_PWD@localhost:1521/$ORACLE_SID as sysdba <<EOF
WHENEVER SQLERROR CONTINUE

-- Usuwamy ewentualne poprzednie tabele (opcjonalnie)
DROP TABLE dane_firmowe CASCADE CONSTRAINTS;
DROP TABLE dane_kontaktowe CASCADE CONSTRAINTS;
DROP TABLE dane_osobowe CASCADE CONSTRAINTS;

CREATE TABLE dane_osobowe (
    osoba_id       VARCHAR2(36 CHAR) PRIMARY KEY,
    imie           VARCHAR2(60 CHAR),
    nazwisko       VARCHAR2(60 CHAR),
    data_urodzenia DATE
);

CREATE TABLE dane_kontaktowe (
    osoba_id      VARCHAR2(36 CHAR),
    email         VARCHAR2(100 CHAR),
    telefon       VARCHAR2(60 CHAR),
    ulica         VARCHAR2(100 CHAR),
    numer_domu    VARCHAR2(60 CHAR),
    miasto        VARCHAR2(60 CHAR),
    kod_pocztowy  VARCHAR2(60 CHAR),
    kraj          VARCHAR2(60 CHAR),
    CONSTRAINT fk_dane_kontaktowe_osoba
        FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

CREATE TABLE dane_firmowe (
    osoba_id      VARCHAR2(36 CHAR),
    nazwa_firmy   VARCHAR2(150 CHAR),
    stanowisko    VARCHAR2(255 CHAR),
    branza        VARCHAR2(100 CHAR),
    CONSTRAINT fk_dane_firmowe_osoba
        FOREIGN KEY (osoba_id) REFERENCES dane_osobowe(osoba_id)
);

EXIT;
EOF
"

# 8. ŁADOWANIE DANYCH PRZY UŻYCIU SQL*LOADER
echo "Importowanie danych do tabel..."

for table in dane_osobowe dane_kontaktowe dane_firmowe; do

  echo ">>> Ładowanie dla tabeli: $table"

  # Uwaga: w Oracle 11g/12c czasem trzeba parametry ująć w pojedyncze cudzysłowy,
  # by 'AS SYSDBA' było traktowane jako jeden element.
  docker exec -i $CONTAINER_NAME bash -c "
    cd $SQL_SCRIPT_DIR
    sqlldr 'sys/$ORACLE_PWD@${ORACLE_SID} AS SYSDBA' control=${table}.ctl log=${table}.log bad=${table}.bad
  "

  # Pobierz log i bad na hosta
  docker cp $CONTAINER_NAME:"$SQL_SCRIPT_DIR/${table}.log" "$LOG_DIR/${table}.log" || true
  docker cp $CONTAINER_NAME:"$SQL_SCRIPT_DIR/${table}.bad" "$LOG_DIR/${table}.bad" || echo "Brak pliku .bad dla $table"

done

# 9. WYŚWIETLENIE LOGÓW
echo ""
echo "========================================"
echo "     LOGI SQL*LOADERA Z KONTENERA       "
echo "========================================"

for log_file in "$LOG_DIR"/*.log; do
  echo "--- Zawartość pliku log: $log_file ---"
  cat "$log_file"
  echo "--------------------------------------"
done

# 10. SPRAWDZENIE LICZBY ZAIMPORTOWANYCH REKORDÓW
echo ""
echo "========================================"
echo "  SPRAWDZENIE LICZBY REKORDÓW W TABELACH"
echo "========================================"

docker exec -i $CONTAINER_NAME bash -c "
sqlplus sys/$ORACLE_PWD@localhost:1521/$ORACLE_SID as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

COLUMN tabela        FORMAT A20
COLUMN liczba_rekordow FORMAT 9999999

SELECT 'dane_osobowe'   AS tabela, COUNT(*) AS liczba_rekordow FROM dane_osobowe;
SELECT 'dane_kontaktowe' AS tabela, COUNT(*) AS liczba_rekordow FROM dane_kontaktowe;
SELECT 'dane_firmowe'   AS tabela, COUNT(*) AS liczba_rekordow FROM dane_firmowe;

EXIT;
EOF
"

echo "Import zakończony pomyślnie!"
