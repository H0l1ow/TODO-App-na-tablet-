import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    readonly property var counts: backend.dashboard
    property string statusMessage: ""
    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height + 50
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content
            x: 26; y: 24
            width: scroll.width - 52
            spacing: 22
            RowLayout {
                width: parent.width
                height: 76
                ColumnLayout {
                    spacing: 4; Layout.fillWidth: true
                    Text { text: "DOBRY DZIEŃ — TO TWÓJ PLAN"; color: Theme.accent; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1.6 }
                    Text { text: "Dzień dobry!"; font.pixelSize: 32; font.bold: true; color: Theme.text }
                    Text { text: backend.todayLabel; color: Theme.muted; font.pixelSize: 14 }
                }
                ActionButton {
                    text: "Szybkie zadanie"; onClicked: openQuickTask()
                }
                ActionButton {
                    text: "+  Wpisz zadanie"; primary: false
                    onClicked: { scroll.contentY = Math.max(0, tasksCard.y - 100); taskInput.forceActiveFocus() }
                }
            }
            Row {
                width: parent.width; height: 126; spacing: 15
                StatCard { width: (parent.width - 30)/3; caption: "Postęp dzisiaj"; amount: counts.done + " / " + counts.total; note: "Wykonanych zadań" }
                StatCard { width: (parent.width - 30)/3; caption: "Pozostało do zrobienia"; amount: "" + counts.remaining; note: "Bez pośpiechu" }
                StatCard { width: (parent.width - 30)/3; caption: "Zaległe zadania"; amount: "" + counts.overdue; note: "Jednorazowe z poprzednich dni" }
            }
            Flow {
                id: body
                width: parent.width
                spacing: 16
                height: content.width >= 940 ? Math.max(tasksCard.height, aside.height) : (tasksCard.height + aside.height + 16)
                Rectangle {
                    id: tasksCard
                    width: content.width >= 940 ? Math.floor((body.width - 16) * 0.63) : body.width
                    height: taskContent.implicitHeight + 40
                    radius: 19; color: Theme.surface; border.color: Theme.border
                    Column {
                        id: taskContent
                        x: 20; y: 20; width: parent.width - 40; spacing: 12
                        RowLayout {
                            width: parent.width; height: 35
                            Text { text: "Zadania na dziś"; color: Theme.text; font.pixelSize: 19; font.bold: true; Layout.fillWidth: true }
                            ActionButton {
                                text: "Kopiuj dzień →"; compact: true; primary: false
                                enabled: counts.total > 0
                                onClicked: { copyDayDialog.sourceDate = backend.today; copyDayDialog.open() }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: backend.todayTasks.length === 0
                            text: "Na dziś nie ma zadań. Dodaj pierwsze poniżej lub zaplanuj je na tydzień."
                            wrapMode: Text.WordWrap
                            color: Theme.muted; font.pixelSize: 14
                            topPadding: 20; bottomPadding: 24
                        }
                        Repeater {
                            model: backend.todayTasks
                            delegate: TaskRow {
                                width: taskContent.width
                                task: modelData
                                showCopy: true
                                onCheckRequested: backend.setTaskDone(taskId, backend.today, done)
                                onAssigneeRequested: {
                                    assignmentDialog.taskId = taskId
                                    assignmentDialog.taskTitle = task.title
                                    assignmentDialog.currentMemberId = task.memberId
                                    assignmentDialog.open()
                                }
                                onCopyRequested: {
                                    if (backend.copyTaskToNextDay(taskId, backend.today))
                                        page.statusMessage = "Zadanie zostało skopiowane na jutro."
                                }
                            }
                        }
                        RowLayout {
                            width: parent.width
                            spacing: 8
                            FormInput {
                                id: taskInput
                                Layout.fillWidth: true
                                placeholderText: "Wpisz własne zadanie..."
                                maximumLength: 160
                                onAccepted: addQuickTask()
                            }
                            ActionButton { text: "Dodaj"; compact: true; onClicked: addQuickTask() }
                        }
                        RowLayout {
                            width: parent.width; spacing: 10
                            Text { text: "Przypisz:"; color: Theme.muted; font.pixelSize: 14 }
                            ComboBox {
                                id: todayAssignee
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                model: backend.assignees
                                textRole: "name"
                                font.pixelSize: 14
                            }
                            ActionButton { text: "Szybkie zadanie"; compact: true; primary: false; onClicked: openQuickTask() }
                        }
                        Text {
                            visible: page.statusMessage.length > 0
                            width: parent.width
                            text: page.statusMessage
                            color: Theme.accent; font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                Column {
                    id: aside
                    width: content.width >= 940 ? body.width - tasksCard.width - 16 : body.width
                    spacing: 16
                    height: overdueCard.height + shoppingCard.height + 16
                    Rectangle {
                        id: overdueCard
                        width: parent.width
                        height: counts.overdue > 0 ? 90 : 70
                        radius: 16
                        color: counts.overdue > 0 ? Theme.warningSoft : Theme.accentSoft
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 15; spacing: 8
                            Text {
                                text: counts.overdue > 0 ? "⚠  " + counts.overdue + " zaległych zadań" : "✓  Wszystko aktualne"
                                color: counts.overdue > 0 ? Theme.warning : Theme.accent
                                font.pixelSize: 13; font.bold: true; Layout.fillWidth: true
                            }
                            ActionButton {
                                text: "Przenieś na dziś"
                                compact: true; primary: false
                                visible: counts.overdue > 0
                                onClicked: backend.moveOverdueToToday()
                            }
                        }
                    }
                    Rectangle {
                        id: shoppingCard
                        width: parent.width
                        height: shoppingContent.implicitHeight + 35
                        radius: 18; color: Theme.surface; border.color: Theme.border
                        Column {
                            id: shoppingContent
                            x: 18; y: 18; width: parent.width - 36; spacing: 10
                            RowLayout {
                                height: 35; width: parent.width
                                Text { text: "Lista zakupów"; font.pixelSize: 18; font.bold: true; color: Theme.text; Layout.fillWidth: true }
                                Button {
                                    id: openShoppingButton
                                    text: "Otwórz →"; flat: true
                                    contentItem: Text { text: openShoppingButton.text; font.bold: true; color: Theme.accent; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                                    onClicked: { /* Nawigacja przez sygnał do App.qml */ page.openShopping() }
                                }
                            }
                            Text { text: "Lista jest pusta — dodaj produkty w zakładce Zakupy."; visible: backend.shoppingItems.length === 0; color: Theme.muted; wrapMode: Text.WordWrap; font.pixelSize: 13; width: parent.width; topPadding: 8; bottomPadding: 9 }
                            Repeater {
                                model: Math.min(backend.shoppingItems.length, 6)
                                delegate: ShoppingRow {
                                    width: shoppingContent.width
                                    item: backend.shoppingItems[index]
                                    onCheckRequested: backend.setShoppingDone(itemId, bought)
                                }
                            }
                            Text { text: counts.shopping + " do kupienia"; color: Theme.muted; font.pixelSize: 12; topPadding: 6 }
                        }
                    }
                }
            }
        }
    }
    signal openShopping()
    QuickTaskPopup { id: quickTaskPopup }
    AssignmentDialog { id: assignmentDialog }
    CopyDayDialog {
        id: copyDayDialog
        onCopied: page.statusMessage = message
    }
    function selectedAssignee() {
        var options = backend.assignees
        return todayAssignee.currentIndex >= 0 && todayAssignee.currentIndex < options.length
            ? options[todayAssignee.currentIndex].id : -1
    }
    function openQuickTask() {
        quickTaskPopup.targetDate = backend.today
        quickTaskPopup.selectedMemberId = selectedAssignee()
        quickTaskPopup.open()
    }
    function addQuickTask() {
        if (backend.addTask(taskInput.text, backend.today, "once", 0, selectedAssignee())) {
            taskInput.clear()
            page.statusMessage = "Zadanie zostało zapisane."
        }
    }
}
