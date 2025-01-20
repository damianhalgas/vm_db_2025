# Projekt: 

## Opis
Ten projekt umożliwia uruchomienie bazy danych MySQL, MSSQL, PostgreSQL i Oracle w kontenerze Docker.

## Wymagania
- Docker i Docker Compose zainstalowane na komputerze.
- Kod jest przygotowany do działania na Ubuntu Server 24.04.1 LTS x86_64

## Sposób użycia
1. Sklonuj repozytorium:
   ```bash
   git clone https://github.com/damianhalgas/vm_db_2025.git
   cd vm_db_2025
2. Uruchom kontener np. 
   Przejdź do folderu wybranej bazy:
   ```bash
   sudo docker compose up -d
3. Ustaw uprawnienia dla skryptów np.
   ```bash
   chmod +x scripts/import_postgres.sh
4. Sprawdź Uprawnienia docker
   ```bash
   sudo groupadd docker
   sudo usermod -aG docker $USER
5. Uruchom skrypty z folderu script np.
   Dla PostgreSQL
   ```bash
   ./scripts/import_postgres.sh
6. Wejdź w baze SQL dla MySQL:
   ```bash
   sudo docker exec -it mysql-container mysql -u root -p
   ```
   Dla postgresql:
   ```bash
   docker exec -it post-container psql -U myuser -d mydatabase
   ```
   Dla MSSQL
   ```bash
   sudo docker exec -it mssql-container /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P StrongPassword123! -C
   ```
   Dla Oracle
   ```bash
   sudo docker exec -it oracle-container bash
   sqlplus sys/oracle@localhost:1521/XE as sysdba
   sqlplus sys as sysdba
   password: oracle
   StrongPassword123!
   ```
7. W przypadku baz MSSQL musimy ręcznie dodać:
   ```bash
   CREATE DATABASE mydatabase;


