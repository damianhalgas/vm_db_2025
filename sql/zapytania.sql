
--MSSQL
1.
SET STATISTICS TIME ON; 
SELECT * FROM dane_osobowe 
WHERE nazwisko = 'Wilson'; 
SET STATISTICS TIME OFF;

2.
SET STATISTICS TIME ON; 
SELECT dane_osobowe.imie, dane_osobowe.nazwisko, dane_kontaktowe.email, dane_kontaktowe.telefon 
FROM dane_osobowe 
JOIN dane_kontaktowe ON dane_osobowe.osoba_id = dane_kontaktowe.osoba_id 
WHERE dane_kontaktowe.miasto = 'Paulbury'; 
SET STATISTICS TIME OFF;

3.
SET STATISTICS TIME ON; 
SELECT dane_firmowe.branza, 
COUNT(*) AS liczba_pracownikow  
FROM dane_firmowe 
GROUP BY dane_firmowe.branza 
ORDER BY liczba_pracownikow DESC; 
SET STATISTICS TIME OFF;

--Other DB
1.
SELECT * FROM dane_osobowe 
WHERE nazwisko = 'Wilson'; 
 
-- ŁACZY dane tabeli dane_osobowe i dane_kontaktowe
2.
SELECT dane_osobowe.imie, 
dane_osobowe.nazwisko, 
dane_kontaktowe.email, 
dane_kontaktowe.telefon 
FROM dane_osobowe
JOIN dane_kontaktowe 
ON dane_osobowe.osoba_id = dane_kontaktowe.osoba_id
WHERE dane_kontaktowe.miasto = 'Paulbury';

--dane według branży i obliczenie liczby pracowników w każdej z nich, wyświetlanie malejąco
3.
SELECT dane_firmowe.branza, 
COUNT(*) AS liczba_pracownikow 
FROM dane_firmowe 
GROUP BY dane_firmowe.branza 
ORDER BY liczba_pracownikow DESC;
