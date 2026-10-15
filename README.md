# Domowy Plan v0.4.1 - ekran pionowy, poprawka dodawania zadan

**Windows 10 32-bit (x86), Qt 5.15.2 MinGW 8.1, calkowicie offline.**

Ta wersja poprawia blad `NOT NULL constraint failed: tasks.schedule_kind` oraz
uproszcza ekran glowny pod tablet trzymany pionowo. Baza SQLite pozostaje ta
sama; migracja i reset danych nie sa wymagane.

Najpierw przeczytaj `AKTUALIZACJA_v0.4.1.md`.

- Ekran Dzisiaj: lista do zrobienia, postep i dwie akcje dodawania.
- Dolna nawigacja: Dzisiaj / Plan / Zakupy / Wiecej.
- Wiecej: szablony, domownicy, historia, ustawienia, kto odhacza zadania.
- Menu szybkich zadan: przewijane kategorie i lista czynnosci.
- Kopiowanie dnia, zalegle i notatki w sekcjach dodatkowych.
- Rozmiary ikon i akcji zoptymalizowane pod dotyk i czytelnosc.
- Zero internetu, chmury i automatycznych backupow. Backup reczny dostepny.

Kompilacja na PC deweloperskim: `BUDUJ_WIN32.bat`.
Gotowa paczka po kompilacji: `out\DomowyPlan-Win32-x86-v0.4.1.zip`.

Wymagane: `C:\Qt\5.15.2\mingw81_32`, `C:\Qt\Tools\mingw810_32`
i CMake w PATH. Na tablecie wystarczy wynikowy ZIP z EXE, Qt i skryptami.

Ekran tabletu trzeba ustawic w Windows jako **Pionowa (Portret)** w
Ustawienia -> System -> Ekran -> Orientacja wyswietlacza.
Program dostosuje uklad automatycznie do dostepnej szerokosci.

Testy: `python -m unittest discover -s tests -v` (SQLite + testy struktury
zrodel). Nie sa rownowazne z kompilacja Qt i testem na fizycznym tablecie.

## Projekt

# Domowy Plan — Qt Quick / SQLite, offline (v0.3.1)

Dedykowana aplikacja TODO na tablet **Krüger&Matz EDGE 1086** z
**Windows 10 32-bit (x86)**. Program działa bez telefonu, internetu,
chmury, konta i serwera. Wszystkie dane zapisują się lokalnie w SQLite.

## Co zawiera projekt

| Ekran | Funkcje |
|---|---|
| Dzisiaj | Zadania dnia, przypisywanie domownikom, szybkie zadania w układzie dwukolumnowym, kopiowanie na jutro, zaległości, mini-lista zakupów |
| Plan tygodnia | Planowanie, powtarzanie, przypisywanie oraz kopiowanie z wybranego dnia na następny, archiwizacja |
| Zakupy | Lista z ilościami, odhaczanie i usuwanie produktów |
| Domownicy | Lokalni domownicy i przypisane obowiązki |
| Historia | Lista ukończonych oraz statystyki 7/30 dni |
| Ustawienia | Tryb nocny, kopia zapasowa JSON, przywracanie, zamykanie |

### Gdzie zacząć

**[Instrukcja kompilacji oraz instalacji dla Windows 10 x86](docs/KOMPILACJA_I_INSTALACJA_WINDOWS_X86.md)**

W skrócie:

1. Na komputerze Windows zainstaluj **Qt 5.15.2 MinGW 8.1 32-bit**,
   **MinGW 8.1 32-bit** i CMake.
2. Uruchom `BUDUJ_WIN32.bat` lub `scripts/Build-Win32.ps1`.
3. Po kompilacji dostaniesz `out/DomowyPlan-Win32-x86-v0.3.1.zip`.
4. Na tablecie rozpakuj **wynikowy ZIP z EXE**, uruchom `ZAINSTALUJ.bat`.

**Uwaga:** to archiwum zawiera **kod źródłowy oraz skrypty**, a nie gotowy
program `.exe`. W tej sesji nie ma odpowiedniego zestawu Qt/Windows do
kompilacji natywnego EXE.

## Technologie

- C++17 + Qt **5.15.2** / QML / Qt Quick Controls 2
- SQLite przez Qt SQL (`QSQLITE`)
- CMake 3.16+ / MinGW-w64 GCC 8.1.0 i686
- Instalator per-user w PowerShell 5.1 (dostępnym w Windows 10)
- Dwa tryby startu: programowy renderer Qt i domyślny GPU
- Brak SDK sieciowych i telemetrii

## Poprawka v0.3.1

- Zastąpiono niestabilne menu kołowe stałymi panelami: kategorie po lewej, gotowe zadania po prawej.
- Dodano domyślną kategorię "Najczęstsze" z pięcioma skrótami.
- Po dodaniu zadania okno zostaje otwarte, więc można dodać kilka zadań po kolei. "Gotowe" zamyka okno.
- Każde otwarcie resetuje wybór kategorii, ale przejmuje aktualnie wybranego domownika.
- Bez zmian w C++ i schemacie SQLite; istnieje też nakładka zawierająca tylko plik QuickTaskPopup.qml.

## Nowości wersji 0.3

- **Przypisanie w Dzisiaj i Planie tygodnia:** dynamiczne opcje `Wszyscy` + utworzeni domownicy. Po dotknięciu etykiety na wierszu można też zmienić przypisanie istniejącego zadania.
- **Szybkie zadanie:** menu kategorii po lewej i presetów po prawej (Pranie, Sprzątanie, Kuchnia, Zakupy, Ogród, Organizacja) i zestaw gotowych zadań bez pisania.
- **Kopia na następny dzień:** przy każdym zadaniu przycisk `→ Jutro`; przy nagłówku dnia kopiowanie tylko niewykonanych albo wszystkich.
- Nowe kopie powstają jako jednorazowe, niewykonane zadania. Oryginały pozostają bez zmian, wraz z historią ukończenia.
- Kopiowanie nie tworzy drugiej pozycji o tej samej nazwie i dla tej samej osoby, jeśli na kolejny dzień istnieje już taka pozycja, także z harmonogramu cyklicznego.
- **Brak zmian schematu SQLite:** wcześniejsze zadania, domownicy i kopie zapasowe pozostają zgodne.

Presety są na razie w `qml/components/QuickTaskPopup.qml`, a nie edytowane w UI. W kolejnej iteracji można przenieść je do lokalnej bazy, żeby dodawać własne kategorie i skróty.

**Uwaga o zaległych:** kopiowanie nie usuwa oryginalnego, niewykonanego zadania. Nadal może ono figurować jako zaległe; funkcja `Przenieś na dziś` jest osobną operacją. Nie należy używać obu mechanizmów do tego samego zadania bez kontroli duplikatów.

## Konfiguracja w Qt Creator (obecne środowisko)

1. Przed aktualizacją, w **Ustawieniach** starej aplikacji wykonaj kopię zapasową JSON.
2. Rozpakuj nowy ZIP źródeł i otwórz `CMakeLists.txt` w Qt Creator (Kit Qt 5.15.2 MinGW 32-bit).
3. Wybierz **Build → Run CMake**, następnie **Build** i **Run**.
4. Jeżeli używasz skryptu do spakowania EXE, uruchom `BUDUJ_WIN32.bat` — zbuduje `out/DomowyPlan-Win32-x86-v0.3.1.zip`.
5. Nową paczkę na tablecie zainstaluj po zamknięciu aplikacji. Baza przechowywana w AppData nie jest usuwana ani zastępowana.

## Nowości wersji 0.2

- Wymuszona zgodność x86 podczas kompilacji na Windows.
- Automatyczne pakowanie EXE, bibliotek, pluginów i QML przez `windeployqt`.
- Walidacja wszystkich EXE/DLL jako 32-bitowe PE przed utworzeniem ZIP.
- Instalacja i aktualizacja bez administratora, skróty i autostart.
- Klawiatura ekranowa Windows dostępna z menu.
- Lokalny log diagnostyczny i skrypt do jego otwierania.
- Dane SQLite poza folderem programu (aktualizacje nie czyszczą zadań).

## Testy

```sh
python3 -m unittest discover -s tests -v
```

Testy SQLite oraz statyczne testy struktury projektu nie zastępują
kompilacji Qt i próby uruchomienia aplikacji na tablecie.

## Pliki

```text
BUDUJ_WIN32.bat
CMakeLists.txt + CMakePresets.json
src/                 kod C++ (backend + wejście programu)
qml/                 interfejs i zasoby osadzone w EXE
sql/schema.sql       schemat bazy SQLite
scripts/Build-Win32.ps1
packaging/           skrypty instalacji i przenośne launchery
  install/Install-Win32.ps1
  install/Uninstall-Win32.ps1
docs/KOMPILACJA_I_INSTALACJA_WINDOWS_X86.md
tests/
```

## Ograniczenia pierwszych wersji

Brak edycji tytułu istniejącego zadania i powtarzania miesięcznego;
statystyki historyczne są częściowo zależne od bieżącego harmonogramu.
Przywracanie najnowszej kopii zastępuje aktualną bazę. Fizyczny test
dotyku, klawiatury i wydajności na EDGE 1086 jest nadal do wykonania.

## Licencje

Dobór licencji aplikacji i ewentualna dystrybucja bibliotek Qt musi
uwzględniać licencję wykorzystywanej wersji Qt oraz pluginów.
