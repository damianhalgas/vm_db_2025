import chardet
import csv
import uuid
from faker import Faker
import os

# Inicjalizacja Faker
fake = Faker('en_US')

# Funkcja do czyszczenia danych z problematycznych znaków
def clean_data(value):
    if isinstance(value, str):
        return value.replace('"', '').replace("'", '').replace(',', '').strip()
    return value

# Funkcja do generowania danych
def generate_data(rows):
    dane_osobowe = []
    dane_kontaktowe = []
    dane_firmowe = []

    for _ in range(rows):
        # Unikalne ID osoby
        osoba_id = str(uuid.uuid4())
        
        # Dane osobowe
        imie = clean_data(fake.first_name())
        nazwisko = clean_data(fake.last_name())
        data_urodzenia = fake.date_of_birth(minimum_age=18, maximum_age=65).strftime('%Y%m%d')  # Format RRRRMMDD
        dane_osobowe.append([osoba_id, imie, nazwisko, data_urodzenia])

        # Dane kontaktowe
        email = clean_data(fake.email())
        telefon = clean_data(fake.phone_number())
        ulica = clean_data(fake.street_name())
        numer_domu = clean_data(fake.building_number())
        miasto = clean_data(fake.city())
        kod_pocztowy = clean_data(fake.postcode())
        kraj = fake.country()
        dane_kontaktowe.append([
            osoba_id, email, telefon, ulica, numer_domu, miasto, kod_pocztowy, kraj
        ])

        # Dane firmowe
        nazwa_firmy = clean_data(fake.company())
        stanowisko = clean_data(fake.job())
        branza = clean_data(fake.bs().split()[0])
        dane_firmowe.append([osoba_id, nazwa_firmy, stanowisko, branza])

    return dane_osobowe, dane_kontaktowe, dane_firmowe

# Funkcja do zapisywania plików CSV
def save_to_csv(filename, data, headers, encoding):
    with open(filename, mode='w', newline='\n', encoding=encoding) as file:
        writer = csv.writer(file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        writer.writerow(headers)
        writer.writerows(data)

# Tworzenie folderów dla plików CSV
os.makedirs("utf-8", exist_ok=True)

# Generowanie danych 
rows = 20_000
dane_osobowe, dane_kontaktowe, dane_firmowe = generate_data(rows)

# Zapis do plików CSV w UTF-8
save_to_csv('utf-8/dane_osobowe.csv', dane_osobowe, ['osoba_id', 'imie', 'nazwisko', 'data_urodzenia'], 'utf-8')
save_to_csv('utf-8/dane_kontaktowe.csv', dane_kontaktowe, [
    'osoba_id', 'email', 'telefon', 'ulica', 'numer_domu', 'miasto', 'kod_pocztowy', 'kraj'
], 'utf-8')
save_to_csv('utf-8/dane_firmowe.csv', dane_firmowe, ['osoba_id', 'nazwa_firmy', 'stanowisko', 'branza'], 'utf-8')

print(f"Wygenerowano {rows} rekordów w formacie UTF-8.")
