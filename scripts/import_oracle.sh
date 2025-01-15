#!/bin/bash

# Konfiguracja
CONTAINER_NAME="oracle-container"
ORACLE_SID="XE"
ORACLE_PWD="StrongPassword123!"
CSV_SOURCE_DIR="/home/administrator/vm_db_2025/csv/20K"
SQL_SCRIPT_DIR="/tmp/sql_scripts"
LOCAL_LOG_DIR="/home/administrator/oracle_logs"  # Lokalny katalog na logi

# Funkcja do usuwania BOM z plików CSV
remove_bom() {
  local file=$1
  sed -i '1s/^\xEF\xBB\xBF//' "$file"
}

# Sprawdź, czy pliki CSV istnieją
if [ ! -f "$CSV_SOURCE_DIR/dane_osobowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_kontaktowe.csv" ] || \
   [ ! -f "$CSV_SOURCE_DIR/dane_firmowe.csv" ]; then
  echo "Błąd: Jeden lub więcej plików CSV nie istnieje w katalogu $CSV_SOURCE_DIR."
  exit 1
fi

# Usuń BOM z plików CSV
echo "Usuwanie BOM z plików CSV..."
remove_bom "$CSV_SOURCE_DIR/dane_osobowe.csv"
remove_bom "$CSV_SOURCE_DIR/dane_kontaktowe.csv"
remove_bom "$CSV_SOURCE_DIR/dane_firmowe.csv"

# Uruchom kontener Oracle
echo "Uruchamianie kontenera Oracle..."
docker-compose up -d $CONTAINER_NAME

# Poczekaj, aż Oracle się uruchomi
echo "Czekanie na pełne uruchomienie Oracle..."
sleep 120

# Sprawdź status kontenera
if ! docker ps | grep -q $CONTAINER_NAME; then
  echo "Kontener $CONTAINER_NAME nie działa. Sprawdź logi kontenera."
  exit 1
fi

# Utwórz katalogi na logi i skrypty SQL w kontenerze
docker exec -i $CONTAINER_NAME bash -c "mkdir -p $SQL_SCRIPT_DIR"

# Kopiowanie plików CSV do kontenera
echo "Kopiowanie plików CSV do kontenera Oracle..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# Tworzenie tabel i importowanie danych
echo "Tworzenie tabel i importowanie danych..."
docker exec -i $CONTAINER_NAME bash -c "
sqlplus sys/$ORACLE_PWD@localhost:1521/$ORACLE_SID as sysdba <<EOF
-- Tworzenie tabel
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
COMMIT;

-- Importowanie danych
HOST sqlldr userid=sys/$ORACLE_PWD@localhost:1521/$ORACLE_SID as sysdba control=$SQL_SCRIPT_DIR/dane_osobowe.ctl log=$SQL_SCRIPT_DIR/dane_osobowe.log bad=$SQL_SCRIPT_DIR/dane_osobowe.bad
HOST sqlldr userid=sys/$ORACLE_PWD@localhost:1521/$ORACLE_SID as sysdba control=$SQL_SCRIPT_DIR/dane_kontaktowe.ctl log=$SQL_SCRIPT_DIR/dane_kontaktowe.log bad=$SQL_SCRIPT_DIR/dane_kontaktowe.bad
HOST sqlldr userid=sys/$ORACLE_PWD@localhost:1521/$ORACLE_SID as sysdba control=$SQL_SCRIPT_DIR/dane_firmowe.ctl log=$SQL_SCRIPT_DIR/dane_firmowe.log bad=$SQL_SCRIPT_DIR/dane_firmowe.bad

EOF
"

# Skopiuj logi z kontenera na lokalny system
echo "Kopiowanie logów z kontenera na lokalny system..."
mkdir -p $LOCAL_LOG_DIR
docker cp $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.log" "$LOCAL_LOG_DIR/"
docker cp $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.log" "$LOCAL_LOG_DIR/"
docker cp $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.log" "$LOCAL_LOG_DIR/"

echo "Import zakończony pomyślnie! Logi znajdują się w katalogu: $LOCAL_LOG_DIR"
