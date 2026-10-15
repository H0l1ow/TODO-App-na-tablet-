import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property string feedback: ""
    property var backups: backend.availableBackups()

    Flickable { anchors.fill: parent; clip: true; contentWidth: width;
        contentHeight: content.implicitHeight + 50
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout { id: content; x: 24; y: 22; width: parent.width-48; spacing: 16
            Text { text: "Ustawienia urządzenia"; font.pixelSize: Math.max(11, Math.round(30 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
            Text { text: "Wszystkie dane pozostają na tablecie. Żadne zadania nie są wysyłane do internetu.";
                font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: appearance.implicitHeight+35;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: appearance; anchors.fill: parent; anchors.margins: 16; spacing: 10
                    Text { text: "Wygląd i czytelność"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        ActionButton { text: "☀ Jasny"; primary: backend.themeMode === "light"; onClicked: backend.setThemeMode("light") }
                        ActionButton { text: "☾ Ciemny"; primary: backend.themeMode === "dark"; onClicked: backend.setThemeMode("dark") }
                        ActionButton { text: "◷ Auto"; primary: backend.themeMode === "auto"; onClicked: backend.setThemeMode("auto") }
                    }
                    Text { text: "Tryb automatyczny: 21:00–07:00 według zegara tabletu.";
                        color: Theme.muted; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
                    RowLayout { Layout.fillWidth: true
                        Text { text: "Skala czcionek: " + backend.fontScale + "%"; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.text }
                        Slider { id: sizeSlider; Layout.fillWidth: true; from: 85; to: 135; stepSize: 5;
                            value: backend.fontScale; onMoved: backend.setFontScale(Math.round(value)) }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: backupContent.implicitHeight+35;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: backupContent; anchors.fill: parent; anchors.margins: 16; spacing: 11
                    Text { text: "Ręczna kopia zapasowa"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                    Text { text: "Automatyczne kopie są wyłączone. Możesz utworzyć kopię JSON w Dokumentach lub wskazanym folderze USB.";
                        color: Theme.muted; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    ActionButton { text: "Zapisz kopię w Dokumentach"; onClicked: {
                        var path=backend.backupNow(); page.feedback=path ? "Zapisano: "+path : backend.errorMessage
                        page.backups=backend.availableBackups()
                    } }
                    RowLayout { Layout.fillWidth: true
                        FormInput { id: usbDir; Layout.fillWidth: true; placeholderText: "Folder pendrive, np. E:\\" }
                        ActionButton { text: "Eksportuj na USB"; compact: true; primary: false;
                            onClicked: {
                                var output=backend.backupToDirectory(usbDir.text)
                                page.feedback=output ? "Zapisano kopię USB: "+output : backend.errorMessage
                                page.backups=backend.availableBackups()
                            } }
                    }
                    Text { text: "Przywróć wybraną kopię (zastępuje obecne dane):";
                        color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
                    ListView { Layout.fillWidth: true; Layout.preferredHeight: Math.min(260,Math.max(58,page.backups.length*55));
                        model: page.backups; clip: true; spacing: 6
                        delegate: RowLayout { width: ListView.view ? ListView.view.width - 4 : 560; height: 52
                            Text { text: modelData.modified + " · " + modelData.name; Layout.fillWidth: true;
                                font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); color: Theme.text; elide: Text.ElideRight }
                            ActionButton { text: "Przywróć"; danger: true; primary: false; compact: true;
                                onClicked: { page.restorePath=modelData.path; confirmRestore.open() } }
                        }
                    }
                    ActionButton { text: "Odśwież listę kopii"; compact: true; primary: false;
                        onClicked: page.backups=backend.availableBackups() }
                    RowLayout { Layout.fillWidth: true
                        FormInput { id: restoreFromUsb; Layout.fillWidth: true;
                            placeholderText: "Ścieżka do kopii na USB, np. E:\\domowy-plan-....json" }
                        ActionButton { text: "Otwórz kopię USB"; compact: true; primary: false;
                            onClicked: { page.restorePath = restoreFromUsb.text; confirmRestore.open() } }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: infoContent.implicitHeight+35;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: infoContent; anchors.fill: parent; anchors.margins: 16; spacing: 10
                    Text { text: "Informacje techniczne"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                    Text { text: "Wersja 0.4.0 · Qt 5.15.2 · Windows x86"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
                    Text { text: "Baza SQLite: " + backend.databasePath;
                        color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                    Text { text: "Rozmiar pliku bazy: " + Math.ceil(backend.databaseBytes/1024) + " KB";
                        color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                    Text { text: "Data z systemu: " + backend.today + ". Upewnij się, że zegar jest ustawiony prawidłowo.";
                        color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
                    RowLayout { Layout.fillWidth: true
                        ActionButton { text: "Klawiatura Windows"; primary: false; onClicked: backend.showOnScreenKeyboard() }
                        ActionButton { text: "Wyjdź z aplikacji"; danger: true; primary: false; onClicked: backend.exitApplication() }
                    }
                }
            }
            Text { text: page.feedback; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.accent;
                Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
        }
    }
    property string restorePath: ""
    Dialog { id: confirmRestore; title: "Na pewno przywrócić dane?"; modal: true;
        x: (page.width-width)/2; y: (page.height-height)/2; standardButtons: Dialog.Yes | Dialog.No
        onAccepted: { if (backend.restoreBackup(page.restorePath)) page.feedback="Przywrócono kopię.";
            else page.feedback=backend.errorMessage }
        contentItem: Text { width: 340; color: Theme.text; wrapMode: Text.WordWrap;
            text: "Zastąpisz wszystkie bieżące zadania, zakupy i szablony zawartością wybranej kopii JSON." }
    }
}
