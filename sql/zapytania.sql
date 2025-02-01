--Other DB
1.
SELECT * FROM dane_osobowe 
WHERE nazwisko = 'Wilson'; 
 
--dane według branży i obliczenie liczby pracowników w każdej z nich, wyświetlanie malejąco
2.
SELECT dane_firmowe.branza, 
COUNT(*) AS liczba_pracownikow 
FROM dane_firmowe 
GROUP BY dane_firmowe.branza 
ORDER BY liczba_pracownikow DESC;

--MSSQL
1.
SET STATISTICS TIME ON; 
SELECT * FROM dane_osobowe 
WHERE nazwisko = 'Wilson'; 
SET STATISTICS TIME OFF;

2.
SET STATISTICS TIME ON; 
SELECT dane_firmowe.branza, 
COUNT(*) AS liczba_pracownikow  
FROM dane_firmowe 
GROUP BY dane_firmowe.branza 
ORDER BY liczba_pracownikow DESC; 
SET STATISTICS TIME OFF;