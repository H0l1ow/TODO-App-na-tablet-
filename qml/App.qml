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
    minimumWidth: 340
    minimumHeight: 530
    color: Theme.background

    property int pageIndex: 0
    // The EDGE 1086 is mounted vertically. Desktop preview remains usable in landscape.
    readonly property bool portraitLayout: width < height || width < 850
    readonly property var pageUrls: [
        "qrc:/qml/pages/TodayPage.qml", "qrc:/qml/pages/WeekPage.qml",
        "qrc:/qml/pages/ShoppingPage.qml", "qrc:/qml/pages/QuickTemplatesPage.qml",
        "qrc:/qml/pages/MembersPage.qml", "qrc:/qml/pages/HistoryPage.qml",
        "qrc:/qml/pages/SettingsPage.qml"
    ]
    readonly property var pageNames: ["Dzisiaj", "Plan", "Zakupy", "Szybkie zadania",
                                      "Domownicy", "Historia", "Ustawienia"]
    readonly property var bottomTabs: [
        {"label":"Dzisiaj", "symbol":"\u2713", "page":0},
        {"label":"Plan", "symbol":"\u25a6", "page":1},
        {"label":"Zakupy", "symbol":"\u25a4", "page":2},
        {"label":"Wi\u0119cej", "symbol":"\u2261", "page":-1}
    ]

    function openPage(index) {
        if (index < 0) moreDialog.open()
        else { pageIndex = index; moreDialog.close() }
    }

    Shortcut { sequence: "F11"; onActivated: root.visibility = root.visibility === Window.FullScreen ? Window.Maximized : Window.FullScreen }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            visible: !root.portraitLayout
            Layout.preferredWidth: visible ? 204 : 0
            Layout.fillHeight: true
            color: Theme.sidebar
            border.color: Theme.border
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4
                Text { text: "Domowy Plan"; color: Theme.text; font.bold: true; font.pixelSize: 20;
                       Layout.topMargin: 17; Layout.bottomMargin: 22 }
                SideNav { Layout.fillWidth: true; text: "Dzisiaj"; iconText: "\u2713"; selected: root.pageIndex === 0; onClicked: root.openPage(0) }
                SideNav { Layout.fillWidth: true; text: "Plan tygodnia"; iconText: "\u25a6"; selected: root.pageIndex === 1; onClicked: root.openPage(1) }
                SideNav { Layout.fillWidth: true; text: "Zakupy"; iconText: "\u25a4"; selected: root.pageIndex === 2; onClicked: root.openPage(2) }
                SideNav { Layout.fillWidth: true; text: "Szybkie zadania"; iconText: "\u2606"; selected: root.pageIndex === 3; onClicked: root.openPage(3) }
                SideNav { Layout.fillWidth: true; text: "Domownicy"; iconText: "\u25cb"; selected: root.pageIndex === 4; onClicked: root.openPage(4) }
                SideNav { Layout.fillWidth: true; text: "Historia"; iconText: "\u25f7"; selected: root.pageIndex === 5; onClicked: root.openPage(5) }
                SideNav { Layout.fillWidth: true; text: "Ustawienia"; iconText: "\u2699"; selected: root.pageIndex === 6; onClicked: root.openPage(6) }
                Item { Layout.fillHeight: true }
                ActionButton { Layout.fillWidth: true; text: "Klawiatura ekranowa"; compact: true; primary: false;
                    onClicked: backend.showOnScreenKeyboard() }
                Text { text: "v0.4.1"; color: Theme.muted; font.pixelSize: 11; Layout.topMargin: 9 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.portraitLayout ? 54 : 58
                color: Theme.surface
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.portraitLayout ? 17 : 23
                    anchors.rightMargin: root.portraitLayout ? 17 : 23
                    spacing: 10
                    Text { text: root.portraitLayout ? "Domowy Plan" : root.pageNames[root.pageIndex];
                        Layout.fillWidth: true; font.pixelSize: 18; font.bold: true; color: Theme.text;
                        elide: Text.ElideRight }
                    Text { visible: root.portraitLayout; text: root.pageNames[root.pageIndex];
                        font.pixelSize: 13; color: Theme.muted; elide: Text.ElideRight }
                    ActionButton {
                        visible: !root.portraitLayout && backend.undoLabel.length > 0
                        text: "Cofnij"; compact: true; primary: false
                        onClicked: backend.undoLast()
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
                    if (item && item.openShopping)
                        item.openShopping.connect(function() { root.pageIndex = 2 })
                }
            }

            Rectangle {
                visible: backend.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 58 : 0
                color: Theme.warningSoft
                Text {
                    anchors.fill: parent
                    anchors.margins: 10
                    text: "Uwaga: " + backend.errorMessage
                    color: Theme.warning; font.pixelSize: 13
                    wrapMode: Text.WordWrap; maximumLineCount: 3
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                visible: root.portraitLayout
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 74 : 0
                color: Theme.surface
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 4
                    Repeater {
                        model: root.bottomTabs
                        delegate: Button {
                            id: tab
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property bool selected: modelData.page === -1 ? root.pageIndex >= 3 : root.pageIndex === modelData.page
                            background: Rectangle { color: tab.selected ? Theme.accentSoft : "transparent"; radius: 11 }
                            contentItem: ColumnLayout {
                                spacing: 1
                                Text { text: modelData.symbol; Layout.alignment: Qt.AlignHCenter;
                                    font.family: "Segoe UI Symbol"; font.pixelSize: 17;
                                    color: tab.selected ? Theme.accent : Theme.muted }
                                Text { text: modelData.label; Layout.alignment: Qt.AlignHCenter;
                                    font.pixelSize: 12; font.bold: tab.selected;
                                    color: tab.selected ? Theme.accent : Theme.text }
                            }
                            onClicked: root.openPage(modelData.page)
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: moreDialog
        title: "Wi\u0119cej"
        modal: true; focus: true; dim: true
        standardButtons: Dialog.NoButton
        width: Math.min(445, root.width - 24)
        height: Math.min(610, root.height - 105)
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        padding: 15
        background: Rectangle { color: Theme.surface; radius: 16; border.color: Theme.border }
        contentItem: ColumnLayout {
            spacing: 9
            Repeater {
                model: [
                    {"title":"Szybkie zadania i szablony", "page":3},
                    {"title":"Domownicy", "page":4},
                    {"title":"Historia i statystyki", "page":5},
                    {"title":"Ustawienia", "page":6}
                ]
                delegate: ActionButton {
                    Layout.fillWidth: true
                    text: modelData.title; primary: false
                    onClicked: root.openPage(modelData.page)
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border; Layout.topMargin: 5 }
            Text { text: "Kto odhacza zadania?"; color: Theme.muted; font.pixelSize: 13 }
            ComboBox {
                id: actingPerson
                Layout.fillWidth: true; Layout.preferredHeight: 46
                model: backend.assignees; textRole: "name"
                function updateSelection() {
                    var list = backend.assignees
                    for (var i = 0; i < list.length; ++i) {
                        if (list[i].id === backend.activeMemberId) { currentIndex = i; return }
                    }
                    currentIndex = 0
                }
                Component.onCompleted: updateSelection()
                onActivated: {
                    var list = backend.assignees
                    if (currentIndex >= 0 && currentIndex < list.length)
                        backend.setActiveMemberId(list[currentIndex].id)
                }
                Connections { target: backend; function onDataChanged() { actingPerson.updateSelection() } }
            }
            ActionButton { text: "Cofnij ostatni\u0105 operacj\u0119"; Layout.fillWidth: true;
                primary: false; enabled: backend.undoLabel.length > 0; onClicked: backend.undoLast() }
            ActionButton { text: "Klawiatura ekranowa"; Layout.fillWidth: true;
                primary: false; onClicked: backend.showOnScreenKeyboard() }
            Item { Layout.fillHeight: true }
            ActionButton { text: "Zamknij"; Layout.fillWidth: true; onClicked: moreDialog.close() }
        }
    }
}
