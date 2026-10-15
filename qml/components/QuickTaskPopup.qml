import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

// Fixed two-panel quick picker. No orbital positions and no view switching.
// All controls stay laid out when the dialog is reopened.
Popup {
    id: root
    property string targetDate: backend.today
    property int selectedMemberId: -1
    property int categoryIndex: 0
    property string statusMessage: ""
    property int addedCount: 0
    // Snapshot prevents ComboBox from resetting when tasks refresh the backend.
    property var assigneeOptions: []
    readonly property var categories: [
        { name: "Najcz\u0119stsze", shortName: "Najcz\u0119stsze", symbol: "\u2605", tasks: [
            "Wstawi\u0107 pranie", "Wynie\u015b\u0107 \u015bmieci", "Opr\u00f3\u017cni\u0107 zmywark\u0119",
            "Odkurzy\u0107 mieszkanie", "Zrobi\u0107 zakupy" ] },
        { name: "Pranie", shortName: "Pranie", symbol: "◉", tasks: [
            "Wstawić pranie", "Rozwiesić pranie", "Poskładać pranie", "Wyprasować ubrania", "Zmienić pościel" ] },
        { name: "Sprzątanie", shortName: "Porządki", symbol: "✦", tasks: [
            "Odkurzyć mieszkanie", "Umyć podłogę", "Zetrzeć kurze", "Wynieść śmieci", "Umyć łazienkę" ] },
        { name: "Kuchnia", shortName: "Kuchnia", symbol: "▤", tasks: [
            "Opróżnić zmywarkę", "Wstawić zmywarkę", "Przygotować obiad", "Umyć blaty", "Posprzątać kuchnię" ] },
        { name: "Zakupy", shortName: "Zakupy", symbol: "▣", tasks: [
            "Zrobić zakupy", "Uzupełnić listę zakupów", "Odebrać paczkę", "Kupić środki czystości" ] },
        { name: "Ogród", shortName: "Ogród", symbol: "❀", tasks: [
            "Podlać rośliny", "Skosić trawnik", "Posprzątać ogród", "Wynieść odpady zielone" ] },
        { name: "Organizacja", shortName: "Organizacja", symbol: "◎", tasks: [
            "Opłacić rachunki", "Przejrzeć pocztę", "Zrobić porządek w szafie", "Przygotować rzeczy na jutro" ] }
    ]
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(790, (parent ? parent.width : 830) - 32)
    height: Math.min(625, (parent ? parent.height : 650) - 24)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    padding: 16
    background: Rectangle {
        radius: 20
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
    }

    onOpened: {
        categoryIndex = 0
        statusMessage = ""
        addedCount = 0
        assigneeOptions = backend.assignees
        var assignees = assigneeOptions
        var memberIndex = 0
        for (var i = 0; i < assignees.length; ++i) {
            if (assignees[i].id === selectedMemberId) {
                memberIndex = i
                break
            }
        }
        quickAssignee.currentIndex = memberIndex
        categoryList.positionViewAtBeginning()
        taskList.positionViewAtBeginning()
    }

    function addPreset(title) {
        var assignees = assigneeOptions
        var selected = quickAssignee.currentIndex
        var person = selected >= 0 && selected < assignees.length
            ? assignees[selected].id : -1
        if (backend.addTask(title, targetDate, "once", 0, person)) {
            addedCount += 1
            statusMessage = "\u2713  Dodano: " + title
            // Keep the dialog open to make adding several tasks fast.
        } else {
            statusMessage = "Nie uda\u0142o si\u0119 doda\u0107 zadania."
        }
    }

    contentItem: ColumnLayout {
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 12
            Text {
                text: "Szybkie zadania"
                font.pixelSize: 24
                font.bold: true
                color: Theme.text
                Layout.fillWidth: true
            }
            ActionButton {
                text: "\u00d7"
                compact: true
                primary: false
                onClicked: root.close()
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Wybierz kategori\u0119 po lewej, a potem zadanie po prawej. Bez wpisywania."
            color: Theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
            spacing: 12

            Rectangle {
                id: categoryPanel
                Layout.preferredWidth: Math.min(205, Math.max(165, root.width * 0.27))
                Layout.fillHeight: true
                radius: 14
                color: Theme.surfaceMuted
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8
                    Text {
                        text: "KATEGORIE"
                        color: Theme.muted
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.topMargin: 5
                    }
                    ListView {
                        id: categoryList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.categories
                        spacing: 5
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Button {
                            id: categoryButton
                            width: ListView.view ? ListView.view.width - 8 : 170
                            height: 48
                            text: modelData.name
                            readonly property bool selected: root.categoryIndex === index
                            background: Rectangle {
                                radius: 10
                                color: categoryButton.selected ? Theme.accentSoft : Theme.surface
                                border.color: categoryButton.selected ? Theme.accent : Theme.border
                                border.width: categoryButton.selected ? 2 : 1
                            }
                            contentItem: RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.symbol
                                    Layout.preferredWidth: 21
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Theme.accent
                                    font.pixelSize: 18
                                }
                                Text {
                                    text: categoryButton.text
                                    Layout.fillWidth: true
                                    color: Theme.text
                                    font.pixelSize: 13
                                    font.bold: categoryButton.selected
                                    elide: Text.ElideRight
                                }
                            }
                            onClicked: {
                                root.categoryIndex = index
                                taskList.positionViewAtBeginning()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: taskPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Theme.surface
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 9
                    Text {
                        text: root.categories[root.categoryIndex].name
                        font.pixelSize: 19
                        font.bold: true
                        color: Theme.text
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Dotknij zadania, aby je doda\u0107."
                        color: Theme.muted
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                    ListView {
                        id: taskList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.categories[root.categoryIndex].tasks
                        spacing: 8
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Button {
                            id: taskButton
                            width: ListView.view ? ListView.view.width - 8 : 300
                            height: 55
                            text: modelData
                            background: Rectangle {
                                radius: 11
                                color: taskButton.down ? Theme.accentSoft : Theme.surfaceMuted
                                border.color: taskButton.down ? Theme.accent : Theme.border
                            }
                            contentItem: RowLayout {
                                spacing: 8
                                Text {
                                    text: taskButton.text
                                    Layout.fillWidth: true
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    text: "+"
                                    color: Theme.accent
                                    font.pixelSize: 25
                                    font.bold: true
                                }
                            }
                            onClicked: root.addPreset(modelData)
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 10
            Text {
                text: "Dla kogo?"
                color: Theme.muted
                font.pixelSize: 14
            }
            ComboBox {
                id: quickAssignee
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                model: root.assigneeOptions
                textRole: "name"
                font.pixelSize: 15
            }
            ActionButton {
                text: "Gotowe"
                compact: true
                onClicked: root.close()
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            text: root.statusMessage.length > 0 ? root.statusMessage : "Szybki wyb\u00f3r bez klawiatury"
            color: root.statusMessage.length > 0 ? Theme.accent : Theme.muted
            font.pixelSize: 12
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
