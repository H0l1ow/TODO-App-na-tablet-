import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

Dialog {
    id: root
    property string sourceDate: backend.today
    signal copied(string message)
    title: "Skopiuj plan na jutro"
    modal: true
    dim: true
    focus: true
    width: Math.min(390, (parent ? parent.width : 430) - 30)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    padding: 18
    standardButtons: Dialog.NoButton
    background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: 17 }

    function execute(includeCompleted) {
        var result = backend.copyDayToNextDay(sourceDate, includeCompleted)
        if (!result.ok) return
        var msg = "Skopiowano " + result.copied + " zadań na " + result.targetDate + "."
        if (result.alreadyPresent > 0) msg += " Już zaplanowane: " + result.alreadyPresent + "."
        if (result.excludedCompleted > 0) msg += " Pominięto wykonane: " + result.excludedCompleted + "."
        root.copied(msg)
        root.close()
    }
    contentItem: Column {
        width: parent ? parent.width : 340
        spacing: 13
        Text {
            width: parent.width
            text: backend.dateLabel(root.sourceDate) + " → " + backend.dateLabel(backend.dateOffset(root.sourceDate,1))
            font.pixelSize: 14; color: Theme.muted; wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: "Utworzymy nowe, niewykonane zadania na kolejny dzień. Cykliczne lub skopiowane wcześniej nie zostaną zdublowane."
            color: Theme.text; font.pixelSize: 13; wrapMode: Text.WordWrap
        }
        ActionButton {
            width: parent.width
            height: 53
            text: "Kopiuj tylko niewykonane"
            onClicked: root.execute(false)
        }
        ActionButton {
            width: parent.width
            height: 53
            text: "Kopiuj wszystkie zadania"
            primary: false
            onClicked: root.execute(true)
        }
        ActionButton { width: parent.width; compact: true; primary: false; text: "Anuluj"; onClicked: root.close() }
    }
}
