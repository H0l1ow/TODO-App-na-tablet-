# Domowy Plan v0.3 — Windows 10 32-bit (x86)

## Cel

Na Krüger&Matz EDGE 1086 z **32-bitowym Windowsem 10** działa wyłącznie
program i biblioteki **x86**. Procesor może obsługiwać 64 bity, ale
architektura zainstalowanego systemu ma pierwszeństwo.

**Kompilację wykonaj na zwykłym komputerze Windows 10/11 (może być 64-bit).**
Na tablecie 2 GB RAM i 32 GB pamięci instalowanie Qt/CMake jest niepotrzebne.
Do tabletu przenosisz kompletny przenośny katalog z plikiem EXE, bibliotekami
Qt i instalatorem. Urządzenie może pozostać całkowicie offline.

## 1. Zależności na komputerze do kompilacji

- Windows 10/11 (64-bitowy komputer deweloperski jest w porządku)
- **Qt 5.15.2 `win32_mingw81`**, instalowany pod `C:\Qt\5.15.2\mingw81_32`
- **MinGW-w64 8.1.0 `i686` (32-bit)** pod `C:\Qt\Tools\mingw810_32`
- CMake 3.16+ (`cmake.exe` w PATH)
- Python 3 na komputerze deweloperskim (tylko do pozyskania narzędzi
  albo uruchamiania testów; nie jest potrzebny na tablecie)

W Qt należy mieć moduły Qt Core, Gui, Qml, Quick, Quick Controls 2 i Qt SQL
(z wtyczką SQLite). W wariancie bazowym Qt 5.15.2 są to standardowe moduły,
więc nie trzeba instalować Qt WebEngine ani Qt Virtual Keyboard.

### Sposób A: Qt Online Installer

Wybierz architekturę **MinGW 8.1.0 32-bit** w gałęzi Qt 5.15.2 oraz narzędzie
**MinGW 8.1.0 32-bit**. Nie wybieraj `mingw81_64`, `MSVC x64` ani Qt 6.
Jeśli stare komponenty Qt nie są widoczne, użyj poniższego sposobu B.

### Sposób B: aqtinstall z oficjalnego repozytorium Qt

Uruchom PowerShell na komputerze deweloperskim (internet potrzebny tylko
podczas pobierania narzędzi):

```powershell
py -3 -m pip install --upgrade aqtinstall
py -3 -m aqt list-qt windows desktop --arch 5.15.2
py -3 -m aqt list-tool windows desktop tools_mingw

py -3 -m aqt install-qt -O C:\Qt windows desktop 5.15.2 win32_mingw81
py -3 -m aqt install-tool -O C:\Qt windows desktop tools_mingw qt.tools.win32_mingw810
```

Oficjalne repozytoria zawierają warianty
`qt.qt5.5152.win32_mingw81` oraz `qt.tools.win32_mingw810`.
Sprawdź fizyczną lokalizację `qmake.exe` i `g++.exe`; jeśli narzędzie
zainstalowało je w innym folderze, podaj go skryptowi `Build-Win32.ps1`.

Źródła pakietów Qt:
- https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt5_5152/
- https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/tools_mingw/
- https://aqtinstall.readthedocs.io/en/stable/getting_started.html

## 2. Zbuduj i spakuj program na komputerze deweloperskim

W katalogu źródeł uruchom `BUDUJ_WIN32.bat` (ustawienia standardowe) albo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Win32.ps1 `
  -QtRoot 'C:\Qt\5.15.2\mingw81_32' `
  -MingwRoot 'C:\Qt\Tools\mingw810_32'
```

Skrypt wykonuje kolejno:

1. Sprawdza dokładnie wersję Qt (5.15.2), wersję MinGW (8.1.x/i686)
   i architekturę `Qt5Core.dll`.
2. Konfiguruje CMake dla 32-bitowego Windows i kompiluje `Release`
   maksymalnie w dwóch równoległych zadaniach.
3. Uruchamia `windeployqt --qmldir`, aby spakować zależności Qt/QML.
4. Dopina dynamiczną wtyczkę `sqldrivers/qsqlite.dll` oraz runtime MinGW.
5. Sprawdza nagłówki PE **wszystkich EXE/DLL**; odrzuca x64.
6. Tworzy ZIP: `out\DomowyPlan-Win32-x86-v0.3.zip`.

Jeżeli projekt był wcześniej kompilowany jako x64, usuń katalog
`out\build-win32-release`, aby nie używać starego cache CMake.

**W ZIP znajdują się pliki wykonywalne dopiero po udanej kompilacji na
Windows.** ZIP ze źródłami projektu nie zawiera gotowego `DomowyPlan.exe`.

## 3. Instalacja na tablecie Windows 10 x86

1. Skopiuj `DomowyPlan-Win32-x86-v0.3.zip` na pendrive.
2. Rozpakuj ZIP na tablecie. Otwórz wypakowany katalog `DomowyPlan`.
3. Kliknij dwukrotnie `ZAINSTALUJ.bat`.
4. Instalator kopiuje program do:
   `%LOCALAPPDATA%\Programs\DomowyPlan`.
5. Zostaną utworzone skróty w Menu Start i na pulpicie.
6. Wybierz autostart przy logowaniu użytkownika Windows (zalecany
   dla tabletu dedykowanego).
7. Uruchom skrót **Domowy Plan**. Aplikacja otworzy się w pełnym ekranie.

Nie potrzeba konta administratora ani połączenia internetowego.

### Bez instalowania

Możesz także bezpośrednio kliknąć `URUCHOM.bat` w rozpakowanym katalogu.
Wtedy program pozostaje przenośny; baza nadal zapisuje się w folderze
profilu użytkownika. `URUCHOM_GPU.bat` uruchamia wariant korzystający
z domyślnego renderera graficznego.

### Tryb kompatybilny z Intel Atom

`URUCHOM.bat` ustawia `QT_QUICK_BACKEND=software`, omijając problemy
starszych sterowników OpenGL. Jeśli interfejs jest płynniejszy przy pracy
z GPU i działa stabilnie, przetestuj `URUCHOM_GPU.bat`.

Na tablecie nie instaluj narzędzi Qt, MinGW ani Visual C++ Redistributable,
jeśli komplet zależności MinGW został już spakowany.

## 4. Aktualizacja z v0.2 na v0.3

Nowa wersja nie dodaje tabel ani kolumn: lokalna baza danych jest odczytywana bez migracji. **Nie usuwaj folderu AppData** i nie wykonuj czystej instalacji systemu.

- **Qt Creator:** otwórz nowe źródła, wykonaj `Build → Run CMake`, potem `Build` i `Run`.
- **Tablet:** zamknij starą aplikację, skopiuj nowy wynikowy ZIP z EXE na tablet i uruchom `ZAINSTALUJ.bat`. Program zostanie zaktualizowany, dane pozostaną w profilu Windows.
- **Backup:** przed testami zalecana jest kopia JSON w Ustawieniach oraz przeniesienie jej na pendrive.

## 5. Dane i aktualizacje

- Baza: domyślna lokalizacja Qt `QStandardPaths::AppDataLocation`,
  zwykle w `%APPDATA%\DomowyPlan\DomowyPlan\domowy_plan.sqlite`.
  Dokładną ścieżkę pokażą Ustawienia aplikacji.
- Kopie JSON: Dokumenty → `DomowyPlan` (przenieś je dodatkowo na pendrive).
- Log diagnostyczny: `%LOCALAPPDATA%\DomowyPlan\diagnostyka.log`.
  Otworzysz go przez `DIAGNOSTYKA.bat`.

**Aktualizacja:** zamknij aplikację i uruchom instalator z nowszej
paczki. Nadpisywane są pliki programu, ale nie baza ani kopie w profilu
użytkownika. Kopię JSON warto wykonać również przed każdą aktualizacją.

**Odinstalowanie:** `ODINSTALUJ.bat` usuwa program i skróty, pozostawiając
bazę, kopie oraz diagnostykę. Nie kasuj folderu z danymi, jeśli chcesz
zachować historię.

## 6. Konfiguracja tabletu

- Uruchamianie pełnoekranowe odbywa się przez `--fullscreen`.
- `F11` przełącza okno i pełny ekran (przy podłączonej klawiaturze).
- Przycisk **Klawiatura ekranowa** w menu aplikacji uruchamia Windows `osk.exe`
  jako zabezpieczenie na wypadek braku automatycznej klawiatury dotykowej.
- Aby zamknąć aplikację, wejdź do Ustawień i kliknij **Zamknij aplikację**.
- Ustaw poprawną datę i godzinę w Windows: zadania cykliczne i tryb nocny
  zależą od lokalnego zegara.
- Skonfiguruj zasilanie i wygaszanie ekranu według potrzeb. Ze względu
  na wiek akumulatora sprawdź jego stan i temperaturę przed pracą ciągłą.

## 7. Problemy

| Objaw | Co sprawdzić |
|---|---|
| „This app can't run on your PC” | ZIP musi być zbudowany jako x86, nie x64. Skrypt odrzuca x64. |
| „Could not find the Qt platform plugin windows” | `platforms/qwindows.dll` i `Qt5Core.dll` muszą być w pakiecie. |
| Pusty ekran / „module QtQuick.Controls is not installed” | `windeployqt --qmldir qml` musi spakować `qml/QtQuick/Controls.2`. |
| „QSQLITE driver not loaded” | Potrzebny `sqldrivers/qsqlite.dll` w wersji 32-bit. |
| Błędy `libgcc_s_dw2-1.dll` / `libstdc++-6.dll` | Muszą być w katalogu EXE; kopiuje je skrypt. |
| Biały ekran / problem z OpenGL | Uruchom `URUCHOM.bat` (renderer software). |
| Klawiatura się nie pojawia | Kliknij „Klawiatura ekranowa” w menu. |
| Program nie zapisuje zadań | Sprawdź miejsce na dysku, prawa do AppData i `diagnostyka.log`. |

## Status weryfikacji

- Wersja Windows 10 x86 jest poprawnie obsługiwana przez **Qt 5.15.2
  `win32_mingw81`**.
- Dostępność oryginalnych archiwów Qt i MinGW x86 została zweryfikowana.
- Testy schematu SQLite i struktury źródeł uruchomiono w środowisku Linux.
- **Program Windows EXE nie został jeszcze zbudowany ani uruchomiony na
  fizycznym EDGE 1086 w tym środowisku.** Kompilację i pakowanie wykona
  dostarczony skrypt na komputerze Windows z Qt x86.

## Licencje

Program jest projektowany jako aplikacja osobista/offline. Biblioteki Qt
mogą podlegać licencjom LGPL/GPL lub komercyjnym, zależnie od komponentów.
Przy dalszym rozpowszechnianiu gotowych pakietów upewnij się, że spełnione
są odpowiednie obowiązki licencyjne, w tym wymagania licencji LGPL.

### Niezależny test gotowego folderu

Na komputerze deweloperskim można dodatkowo uruchomić:

```powershell
py -3 .\scripts\verify_win32_bundle.py .\out\package-win32\DomowyPlan
```

Skrypt sprawdza komplet podstawowych zależności, obecność modułu
QtQuick.Controls 2 oraz nagłówki wszystkich bibliotek EXE/DLL.

### Alternatywa: CMake Presets (CMake 3.21+)

Jeżeli używasz VS Code / CLion / terminala i masz standardowe ścieżki Qt:

```powershell
cmake --preset windows-x86-qt515-mingw81
cmake --build --preset windows-x86-release
```

Preset kompiluje program, ale **nie tworzy pakietu przenośnego**.
Do pełnego pakowania DLL/QML/instalatora uruchom `BUDUJ_WIN32.bat`.
