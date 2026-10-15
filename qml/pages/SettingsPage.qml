import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property string backupMessage: ""
    Flickable {
        id: scroll; anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.height + 50
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content; x: 26; y: 26; width: scroll.width - 52; spacing: 18
            Text { text: "Ustawienia"; font.pixelSize: 30; font.bold: true; color: Theme.text }
            Text { text: "Bez kont, bez chmury i bez połączenia z internetem."; font.pixelSize: 14; color: Theme.muted }
            Rectangle {
                width: parent.width; height: themeContent.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: themeContent; x: 20; y: 20; width: parent.width - 40; spacing: 13
                    Text { text: "Wygląd"; font.pixelSize: 20; font.bold: true; color: Theme.text }
                    Text { text: "Tryb automatyczny: ciemny od 21:00 do 7:00 (zegar tabletu)."; font.pixelSize: 13; color: Theme.muted; width: parent.width; wrapMode: Text.WordWrap }
                    Row {
                        spacing: 10; width: parent.width; height: 45
                        ActionButton { text: "☀ Jasny"; primary: backend.themeMode === "light"; onClicked: backend.setThemeMode("light") }
                        ActionButton { text: "☾ Ciemny"; primary: backend.themeMode === "dark"; onClicked: backend.setThemeMode("dark") }
                        ActionButton { text: "◷ Auto"; primary: backend.themeMode === "auto"; onClicked: backend.setThemeMode("auto") }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: backupContent.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: backupContent; x: 20; y: 20; width: parent.width - 40; spacing: 12
                    Text { text: "Bezpieczeństwo danych"; font.pixelSize: 20; font.bold: true; color: Theme.text }
                    Text { text: "Dane są zapisywane automatycznie w SQLite. Kopię JSON można przenieść na pendrive."; font.pixelSize: 13; color: Theme.muted; width: parent.width; wrapMode: Text.WordWrap }
                    Row { spacing: 10; height: 46
                        ActionButton {
                            text: "Utwórz kopię"; onClicked: {
                                var path = backend.backupNow()
                                page.backupMessage = path ? "Zapisano: " + path : "Nie udało się zapisać kopii."
                            }
                        }
                        ActionButton { text: "Przywróć ostatnią kopię"; primary: false; danger: true; onClicked: restorePopup.open() }
                    }
                    Text { text: page.backupMessage; visible: page.backupMessage.length > 0; font.pixelSize: 12; color: Theme.accent; width: parent.width; wrapMode: Text.WrapAnywhere }
                    Text { text: "Folder kopii: Dokumenty / DomowyPlan"; font.pixelSize: 12; color: Theme.muted }
                }
            }
            Rectangle {
                width: parent.width; height: databaseColumn.implicitHeight + 36
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: databaseColumn; x: 20; y: 18; width: parent.width - 40; spacing: 9
                    Text { text: "Urządzenie"; color: Theme.text; font.pixelSize: 20; font.bold: true }
                    Text { text: "Lokalizacja bazy danych:"; color: Theme.muted; font.pixelSize: 12 }
                    Text { text: backend.databasePath; color: Theme.text; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; width: parent.width }
                    Text { text: "F11 — przełącz pełny ekran. Data i godzina pochodzą z Windows."; color: Theme.muted; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap }
                    Row { height: 43; spacing: 10
                        ActionButton { text: "Zamknij aplikację"; primary: false; onClicked: backend.exitApplication() }
                    }
                }
            }
        }
    }
    Dialog {
        id: restorePopup
        title: "Przywrócić kopię?"
        modal: true; x: (page.width-width)/2; y: (page.height-height)/2
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            if (backend.restoreLatestBackup()) page.backupMessage = "Przywrócono ostatnią kopię zapasową."
            else page.backupMessage = "Nie udało się przywrócić kopii."
        }
        contentItem: Text {
            text: "UWAGA: bieżące zadania, zakupy i ustawienia zostaną zastąpione przez dane z najnowszej kopii JSON."
            width: 340; color: Theme.text; wrapMode: Text.WordWrap; topPadding: 12; bottomPadding: 12
        }
    }
}
