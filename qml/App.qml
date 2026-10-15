import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Window 2.12
import "components"

ApplicationWindow {
    id: root
    title: "Domowy Plan"
    visible: true
    visibility: startFullscreen ? Window.FullScreen : Window.Maximized
    minimumWidth: 960
    minimumHeight: 570
    color: Theme.background

    property int pageIndex: 0
    readonly property var pageUrls: [
        "qrc:/qml/pages/TodayPage.qml",
        "qrc:/qml/pages/WeekPage.qml",
        "qrc:/qml/pages/ShoppingPage.qml",
        "qrc:/qml/pages/QuickTemplatesPage.qml",
        "qrc:/qml/pages/MembersPage.qml",
        "qrc:/qml/pages/HistoryPage.qml",
        "qrc:/qml/pages/SettingsPage.qml"
    ]
    readonly property var pageNames: ["Dzisiaj", "Plan tygodnia", "Zakupy", "Szybkie zadania", "Domownicy", "Historia", "Ustawienia"]

    Shortcut { sequence: "F11"; onActivated: root.visibility = root.visibility === Window.FullScreen ? Window.Maximized : Window.FullScreen }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Theme.sidebar
            border.color: Theme.border
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 19
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 32
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 12
                        color: Theme.accent
                        Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: Math.max(11, Math.round(23 * backend.fontScale / 100)); color: Theme.accentText }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "domowy plan"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                        Text { text: "TWOJA CODZIENNOŚĆ"; font.pixelSize: Math.max(11, Math.round(9 * backend.fontScale / 100)); font.letterSpacing: 1.3; font.bold: true; color: Theme.muted }
                    }
                }
                Text { text: "PRZESTRZEŃ DOMOWA"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(10 * backend.fontScale / 100)); font.bold: true; font.letterSpacing: 1.4; Layout.leftMargin: 12; Layout.bottomMargin: 10 }
                SideNav { Layout.fillWidth: true; text: "Dzisiaj"; iconText: "⌂"; selected: root.pageIndex === 0; onClicked: root.pageIndex = 0 }
                SideNav { Layout.fillWidth: true; text: "Plan tygodnia"; iconText: "▦"; selected: root.pageIndex === 1; onClicked: root.pageIndex = 1 }
                SideNav { Layout.fillWidth: true; text: "Zakupy"; iconText: "▤"; selected: root.pageIndex === 2; onClicked: root.pageIndex = 2 }
                SideNav { Layout.fillWidth: true; text: "Szybkie zadania"; iconText: "★"; selected: root.pageIndex === 3; onClicked: root.pageIndex = 3 }
                SideNav { Layout.fillWidth: true; text: "Domownicy"; iconText: "♙"; selected: root.pageIndex === 4; onClicked: root.pageIndex = 4 }
                SideNav { Layout.fillWidth: true; text: "Historia"; iconText: "◷"; selected: root.pageIndex === 5; onClicked: root.pageIndex = 5 }
                SideNav { Layout.fillWidth: true; text: "Ustawienia"; iconText: "⚙"; selected: root.pageIndex === 6; onClicked: root.pageIndex = 6 }
                Item { Layout.fillHeight: true }
                ActionButton {
                    Layout.fillWidth: true
                    primary: false
                    compact: true
                    text: "Klawiatura ekranowa"
                    onClicked: backend.showOnScreenKeyboard()
                }
                Text { text: "Domowy Plan v0.4"; Layout.topMargin: 10; Layout.leftMargin: 12;
                    color: Theme.muted; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: Theme.background
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 27
                    anchors.rightMargin: 27
                    spacing: 12
                    Text { text: "⌂  Dom / " + root.pageNames[root.pageIndex]; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); Layout.fillWidth: true }
                    Text { text: "Wykonuje:"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
                    ComboBox {
                        id: actingPerson
                        implicitWidth: 155; implicitHeight: 45
                        model: backend.assignees; textRole: "name"
                        Component.onCompleted: updateSelection()
                        function updateSelection() {
                            var options = backend.assignees
                            for (var i=0; i<options.length; ++i)
                                if (options[i].id === backend.activeMemberId) { currentIndex = i; return }
                            currentIndex = 0
                        }
                        onActivated: {
                            var options = backend.assignees
                            if (currentIndex >= 0 && currentIndex < options.length)
                                backend.setActiveMemberId(options[currentIndex].id)
                        }
                        Connections { target: backend; function onDataChanged() { actingPerson.updateSelection() } }
                    }
                    ActionButton { text: "↶ Cofnij"; primary: false; compact: true;
                        enabled: backend.undoLabel.length > 0; onClicked: backend.undoLast() }
                    ActionButton {
                        text: backend.darkMode ? "☀" : "☾"
                        compact: true; primary: false
                        implicitWidth: 46
                        onClicked: backend.setThemeMode(backend.darkMode ? "light" : "dark")
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            }
            Loader {
                id: pageLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: root.pageUrls[root.pageIndex]
                onLoaded: {
                    if (item && item.openShopping) {
                        item.openShopping.connect(function() { root.pageIndex = 2 })
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                visible: backend.errorMessage.length > 0
                color: Theme.warningSoft
                Text {
                    text: "Uwaga: " + backend.errorMessage
                    anchors.fill: parent
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: Theme.warning
                    font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100))
                }
            }
        }
    }
}
