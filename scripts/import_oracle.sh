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

# Utwórz pliki kontrolne
cat > dane_osobowe.ctl << EOF
LOAD DATA
INFILE '$SQL_SCRIPT_DIR/dane_osobowe.csv'
INTO TABLE dane_osobowe
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
  osoba_id,
  imie,
  nazwisko,
  data_urodzenia DATE "YYYY-MM-DD"
)
EOF

cat > dane_kontaktowe.ctl << EOF
LOAD DATA
INFILE '$SQL_SCRIPT_DIR/dane_kontaktowe.csv'
INTO TABLE dane_kontaktowe
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
  osoba_id,
  email,
  telefon,
  ulica,
  numer_domu,
  miasto,
  kod_pocztowy,
  kraj
)
EOF

cat > dane_firmowe.ctl << EOF
LOAD DATA
INFILE '$SQL_SCRIPT_DIR/dane_firmowe.csv'
INTO TABLE dane_firmowe
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
  osoba_id,
  nazwa_firmy,
  stanowisko,
  branza
)
EOF

# Kopiuj pliki kontrolne do kontenera
docker cp dane_osobowe.ctl $CONTAINER_NAME:$SQL_SCRIPT_DIR/
docker cp dane_kontaktowe.ctl $CONTAINER_NAME:$SQL_SCRIPT_DIR/
docker cp dane_firmowe.ctl $CONTAINER_NAME:$SQL_SCRIPT_DIR/

# Kopiowanie plików CSV do kontenera
echo "Kopiowanie plików CSV do kontenera Oracle..."
docker cp "$CSV_SOURCE_DIR/dane_osobowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_osobowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_kontaktowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_kontaktowe.csv"
docker cp "$CSV_SOURCE_DIR/dane_firmowe.csv" $CONTAINER_NAME:"$SQL_SCRIPT_DIR/dane_firmowe.csv"

# Tworzenie tabel i importowanie danych
echo "Tworzenie tabel i importowanie danych..."
docker exec -i $CONTAINER_NAME sqlplus sys as sysdba << EOF
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

exit;
EOF

# Import danych używając SQL*Loader
echo "Importowanie danych..."
docker exec -i $CONTAINER_NAME bash -c "
cd $SQL_SCRIPT_DIR
sqlldr sys as sysdba control=dane_osobowe.ctl
sqlldr sys as sysdba control=dane_kontaktowe.ctl
sqlldr sys as sysdba control=dane_firmowe.ctl
"

# Sprawdź wyniki
docker exec -i $CONTAINER_NAME sqlplus sys as sysdba << EOF
SELECT 'dane_osobowe' as tabela, COUNT(*) as liczba_rekordow FROM dane_osobowe;
SELECT 'dane_kontaktowe' as tabela, COUNT(*) as liczba_rekordow FROM dane_kontaktowe;
SELECT 'dane_firmowe' as tabela, COUNT(*) as liczba_rekordow FROM dane_firmowe;
exit;
EOF

echo "Import zakończony"