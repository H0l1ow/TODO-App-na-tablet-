# Kolejne etapy — Domowy Plan

## Zrealizowane w v0.3

- [x] Przypisywanie / zmiana przypisania, także z Dzisiaj
- [x] Kołowe menu gotowych zadań
- [x] Kopiowanie pojedynczego zadania i dnia na jutro (cały plan lub niewykonane)
- [ ] Edycja kategorii i presetów z interfejsu (dalszy etap)

## Wersja 0.1 (historia)

- Lokalna SQLite, zadania jednorazowe/daily/weekly per dzień
- Dzisiaj, tydzień, zakupy, domownicy, historia, motyw nocny
- Ręczne przenoszenie zaległych i JSON backup/restore
- Pełnoekranowa aplikacja Qt Quick (Windows 10 x86/x64)

## Przed testami na tablecie

- [ ] Ustalić architekturę Windows 10: 32-bit/64-bit
- [ ] Skompilować EXE + wdrożyć zależności `windeployqt`
- [ ] Zweryfikować plugin SQLite oraz wyświetlanie wszystkich ekranów QML
- [ ] Sprawdzić skalowanie Windows (125/150/200%) i 1920×1200
- [ ] Sprawdzić otwieranie klawiatury ekranowej po dotknięciu pól
- [ ] Przetestować powrót ze wstrzymania, wyłączenie/noc, dłuższe działanie
- [ ] Sprawdzić, czy GPU na Atom x5-Z8350 poprawnie renderuje Qt Quick
- [ ] Przetestować instalację na czystym tablecie całkowicie bez internetu

## v0.2

- Edycja zadania (bez utraty historii wcześniejszych wystąpień)
- Wybór dowolnej daty, nie tylko 7 kolejnych dni
- Widok zaległych z wyborem pojedynczych zadań do przeniesienia
- Automatyczna kopia zapasowa, np. 1 raz dziennie po uruchomieniu
- Sprzętowe testy responsywności i pamięci RAM

## v0.3

- Opcjonalne zadania miesięczne i przypomnienia lokalne
- Lepsza historia po przenoszeniu / zmianach planów
- Opcjonalny dotykowy panel klawiatury wewnątrz aplikacji
- Kontrolowany wygaszacz / automatyczne podświetlenie w nocy
