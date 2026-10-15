import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property string selectedDate: backend.today
    property var entries: backend.tasksForDate(selectedDate)
    property int selectedMask: backend.weekdayBit(selectedDate)
    property int toArchive: -1
    property string statusMessage: ""
    Connections {
        target: backend
        function onDataChanged() { page.entries = backend.tasksForDate(page.selectedDate) }
    }
    onSelectedDateChanged: { entries = backend.tasksForDate(selectedDate); selectedMask = backend.weekdayBit(selectedDate) }

    Flickable {
        id: scroll
        anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.height + 44
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content
            x: 26; y: 26; width: scroll.width - 52; spacing: 18
            Text { text: "Plan tygodnia"; font.pixelSize: 30; font.bold: true; color: Theme.text }
            Text { text: "Wybierz dzień, aby zaplanować obowiązki lub zaznaczyć wykonane zadania."; font.pixelSize: 14; color: Theme.muted; width: parent.width; wrapMode: Text.WordWrap }
            Row {
                width: parent.width; height: 98; spacing: 9
                Repeater {
                    model: backend.weekDays
                    delegate: Rectangle {
                        width: (content.width - 54)/7; height: 94
                        radius: 14
                        color: selectedDate === modelData.date ? Theme.accentSoft : Theme.surface
                        border.color: selectedDate === modelData.date ? Theme.accent : Theme.border
                        border.width: selectedDate === modelData.date ? 2 : 1
                        Column {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: modelData.label; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.muted; font.pixelSize: 12 }
                            Text { text: modelData.day; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.text; font.bold: true; font.pixelSize: 23 }
                            Text { text: modelData.done + "/" + modelData.total; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.accent; font.pixelSize: 11 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: page.selectedDate = modelData.date }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: plannedContent.implicitHeight + 36
                radius: 18; border.color: Theme.border; color: Theme.surface
                Column {
                    id: plannedContent; x: 20; y: 18; width: parent.width - 40; spacing: 10
                    RowLayout {
                        width: parent.width; height: 36
                        Text { text: backend.dateLabel(selectedDate); font.pixelSize: 18; font.bold: true; color: Theme.text; Layout.fillWidth: true }
                        ActionButton {
                            text: "Kopiuj dzień →"; compact: true; primary: false
                            enabled: entries.length > 0
                            onClicked: { copyDayDialog.sourceDate = selectedDate; copyDayDialog.open() }
                        }
                    }
                    Text { text: "Brak zaplanowanych zadań."; visible: entries.length === 0; color: Theme.muted; font.pixelSize: 14; topPadding: 16; bottomPadding: 16 }
                    Repeater {
                        model: page.entries
                        delegate: TaskRow {
                            width: plannedContent.width
                            task: modelData
                            showArchive: true
                            showCopy: true
                            onCheckRequested: backend.setTaskDone(taskId, selectedDate, done)
                            onArchiveRequested: { page.toArchive = taskId; archivePopup.open() }
                            onAssigneeRequested: {
                                assignmentDialog.taskId = taskId
                                assignmentDialog.taskTitle = task.title
                                assignmentDialog.currentMemberId = task.memberId
                                assignmentDialog.open()
                            }
                            onCopyRequested: {
                                if (backend.copyTaskToNextDay(taskId, selectedDate))
                                    page.statusMessage = "Zadanie skopiowano na " + backend.dateOffset(selectedDate,1) + "."
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: formContent.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: formContent; x: 20; y: 20; width: parent.width - 40; spacing: 13
                    RowLayout {
                        width: parent.width
                        Text { text: "Zaplanuj nowe zadanie"; color: Theme.text; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
                        ActionButton { text: "Szybkie zadanie"; compact: true; primary: false; onClicked: openQuickTask() }
                    }
                    FormInput { id: taskTitle; width: parent.width; placeholderText: "Co jest do zrobienia?"; maximumLength: 160; onAccepted: saveTask() }
                    RowLayout {
                        width: parent.width; spacing: 10
                        Text { text: "Powtarzanie:"; color: Theme.muted; font.pixelSize: 14 }
                        ComboBox {
                            id: recurrence
                            Layout.preferredWidth: Math.min(230, formContent.width * 0.38)
                            model: ["Jednorazowo", "Codziennie", "Wybrane dni tygodnia"]
                            font.pixelSize: 14
                        }
                        Text { text: "Domownik:"; color: Theme.muted; font.pixelSize: 14 }
                        ComboBox {
                            id: assignee
                            Layout.fillWidth: true
                            model: backend.assignees
                            textRole: "name"
                            font.pixelSize: 14
                        }
                    }
                    Row {
                        width: parent.width; height: 44; spacing: 7
                        visible: recurrence.currentIndex === 2
                        Repeater {
                            model: ["Pn", "Wt", "Śr", "Cz", "Pt", "So", "Nd"]
                            delegate: Button {
                                id: weekday
                                property int dayBit: 1 << index
                                implicitWidth: Math.max(51, (formContent.width - 42) / 7)
                                implicitHeight: 42
                                text: modelData
                                background: Rectangle {
                                    radius: 9; color: (page.selectedMask & weekday.dayBit) !== 0 ? Theme.accent : Theme.surfaceMuted
                                }
                                contentItem: Text {
                                    text: weekday.text; color: (page.selectedMask & weekday.dayBit) !== 0 ? Theme.accentText : Theme.text
                                    font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.selectedMask ^= dayBit
                            }
                        }
                    }
                    RowLayout {
                        width: parent.width
                        Text { text: "Początek: " + selectedDate; color: Theme.muted; font.pixelSize: 13; Layout.fillWidth: true }
                        ActionButton { text: "+ Dodaj zadanie"; onClicked: saveTask() }
                    }
                    Text {
                        width: parent.width; visible: page.statusMessage.length > 0
                        text: page.statusMessage; color: Theme.accent; font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
    QuickTaskPopup { id: quickTaskPopup }
    AssignmentDialog { id: assignmentDialog }
    CopyDayDialog {
        id: copyDayDialog
        onCopied: page.statusMessage = message
    }
    function selectedAssignee() {
        var options = backend.assignees
        return assignee.currentIndex >= 0 && assignee.currentIndex < options.length
            ? options[assignee.currentIndex].id : -1
    }
    function openQuickTask() {
        quickTaskPopup.targetDate = selectedDate
        quickTaskPopup.selectedMemberId = selectedAssignee()
        quickTaskPopup.open()
    }
    function saveTask() {
        var recurrenceKey = recurrence.currentIndex === 1 ? "daily" : recurrence.currentIndex === 2 ? "weekly" : "once"
        if (backend.addTask(taskTitle.text, selectedDate, recurrenceKey, selectedMask, selectedAssignee())) {
            taskTitle.clear()
            recurrence.currentIndex = 0
            assignee.currentIndex = 0
            page.statusMessage = "Zadanie zostało zapisane."
        }
    }
    Dialog {
        id: archivePopup
        title: "Archiwizować zadanie?"
        modal: true
        x: (page.width - width)/2
        y: (page.height - height)/2
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: backend.archiveTask(page.toArchive)
        contentItem: Text { text: "Nie będzie już pokazywane. Wykonania pozostaną w historii."; width: 300; wrapMode: Text.WordWrap; color: Theme.text; topPadding: 12; bottomPadding: 12 }
    }
}
