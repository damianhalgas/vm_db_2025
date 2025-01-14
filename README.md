# Projekt: 

## Opis
Ten projekt umożliwia uruchomienie bazy danych MySQL, MSSQL, PostgreSQL i Oracle w kontenerze Docker.

## Wymagania
- Docker i Docker Compose zainstalowane na komputerze.
- Kod jest przygotowany do działania na Ubuntu Server

## Sposób użycia
1. Sklonuj repozytorium:
   ```bash
   git clone https://github.com/damianhalgas/vm_db_2025.git
   cd vm_db_2025
2. Ustaw uprawnienia dla skryptów np.
   ```bash
   chmod +x scripts/import_postgres.sh
3. Uruchom skrypty z folderu script:
   ```bash
   git clone https://github.com/damianhalgas/vm_db_2025.git
   cd vm_db_2025
4. Sprawdź Uprawnienia docker
   ```bash
   sudo groupadd docker
   sudo usermod -aG docker $USER
