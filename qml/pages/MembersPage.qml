import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property int pendingDeleteId: -1
    Flickable {
        anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.height + 50
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content; x: 26; y: 26; width: parent.width - 52; spacing: 18
            Text { text: "Domownicy"; font.pixelSize: 30; font.bold: true; color: Theme.text }
            Text { text: "Lokalne profile, bez logowania i haseł. Zadania można przypisywać każdemu z domowników."; font.pixelSize: 14; color: Theme.muted; width: parent.width; wrapMode: Text.WordWrap }
            Rectangle {
                width: parent.width; height: membersColumn.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: membersColumn; x: 20; y: 20; width: parent.width - 40; spacing: 12
                    Text { text: "Osoby w domu"; color: Theme.text; font.pixelSize: 20; font.bold: true }
                    Text { text: "Nie dodano jeszcze domowników. Możesz nadal tworzyć zadania wspólne."; visible: backend.members.length === 0; width: parent.width; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: 14; topPadding: 12; bottomPadding: 10 }
                    Repeater {
                        model: backend.members
                        delegate: Item {
                            width: membersColumn.width; height: 69
                            RowLayout {
                                anchors.fill: parent; spacing: 13
                                Rectangle {
                                    Layout.preferredWidth: 42; Layout.preferredHeight: 42
                                    radius: 21; color: modelData.color
                                    Text { anchors.centerIn: parent; text: modelData.initial; color: "#556B61"; font.pixelSize: 19; font.bold: true }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 4
                                    Text { text: modelData.name; color: Theme.text; font.bold: true; font.pixelSize: 15 }
                                    Text { text: modelData.remaining + " do zrobienia na dziś · " + modelData.done + " wykonanych"; color: Theme.muted; font.pixelSize: 12 }
                                }
                                ActionButton {
                                    text: "Usuń"; compact: true; primary: false; danger: true
                                    onClicked: { page.pendingDeleteId = modelData.id; removePopup.open() }
                                }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                        }
                    }
                    RowLayout {
                        width: parent.width; spacing: 10
                        FormInput { id: newMember; Layout.fillWidth: true; placeholderText: "Imię domownika"; maximumLength: 48; onAccepted: addPerson() }
                        ActionButton { text: "+ Dodaj"; onClicked: addPerson() }
                    }
                }
            }
        }
    }
    function addPerson() {
        if (backend.addMember(newMember.text)) newMember.clear()
    }
    Dialog {
        id: removePopup
        title: "Usunąć domownika?"
        modal: true; x: (page.width-width)/2; y: (page.height-height)/2
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: backend.removeMember(page.pendingDeleteId)
        contentItem: Text { text: "Jego zadania staną się wspólne. Historia wykonań pozostanie."; color: Theme.text; width: 295; wrapMode: Text.WordWrap; topPadding: 12; bottomPadding: 12 }
    }
}
