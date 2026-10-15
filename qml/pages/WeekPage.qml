import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property string selectedDate: backend.today
    property string monthAnchor: backend.today
    property var entries: backend.tasksForDate(selectedDate)
    property var monthDays: backend.monthCalendar(monthAnchor)
    property string statusMessage: ""
    property bool monthVisible: false

    function changeMonth(delta) {
        var d = new Date(monthAnchor + "T12:00:00")
        d.setDate(1); d.setMonth(d.getMonth() + delta)
        monthAnchor = Qt.formatDate(d, "yyyy-MM-dd")
    }
    Flickable { id: scroll; anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.implicitHeight + 42
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout { id: content; x: 24; y: 21; width: scroll.width-48; spacing: 16
            RowLayout { Layout.fillWidth: true
                ColumnLayout { Layout.fillWidth: true
                    Text { text: "Plan i kalendarz"; font.pixelSize: Math.max(11, Math.round(30 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                    Text { text: "Zaplanuj, powtarzaj, kopiuj lub edytuj zadania."; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted }
                }
                ActionButton { text: monthVisible ? "Tydzień" : "Miesiąc"; primary: false;
                    onClicked: page.monthVisible = !page.monthVisible }
                ActionButton { text: "+ Nowe zadanie"; onClicked: newTask() }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: page.monthVisible ? 430 : 122;
                radius: 17; color: Theme.surface; border.color: Theme.border
                ColumnLayout { anchors.fill: parent; anchors.margins: 13; spacing: 8
                    RowLayout { visible: page.monthVisible; Layout.fillWidth: true
                        ActionButton { text: "‹"; compact: true; primary: false; onClicked: changeMonth(-1) }
                        Text { Layout.fillWidth: true; text: Qt.formatDate(new Date(monthAnchor+"T12:00:00"), "MMMM yyyy");
                            color: Theme.text; font.pixelSize: Math.max(11, Math.round(17 * backend.fontScale / 100)); font.bold: true; horizontalAlignment: Text.AlignHCenter }
                        ActionButton { text: "›"; compact: true; primary: false; onClicked: changeMonth(1) }
                    }
                    Grid { visible: page.monthVisible; Layout.fillWidth: true; Layout.fillHeight: true;
                        columns: 7; spacing: 5
                        Repeater { model: page.monthDays
                            delegate: Button { id: dayButton
                                width: (content.width - 40 - 30)/7; height: 52
                                text: ""+modelData.day
                                background: Rectangle { color: selectedDate === modelData.date ? Theme.accentSoft : Theme.surfaceMuted;
                                    radius: 10; border.color: selectedDate === modelData.date ? Theme.accent : Theme.border }
                                contentItem: ColumnLayout { spacing: 0
                                    Text { text: dayButton.text; Layout.alignment: Qt.AlignHCenter;
                                        font.pixelSize: Math.max(11, Math.round(16 * backend.fontScale / 100)); color: modelData.currentMonth ? Theme.text : Theme.muted;
                                        font.bold: modelData.today }
                                    Text { text: modelData.done + "/" + modelData.planned; Layout.alignment: Qt.AlignHCenter;
                                        font.pixelSize: Math.max(11, Math.round(11 * backend.fontScale / 100)); color: Theme.accent }
                                }
                                onClicked: page.selectedDate = modelData.date
                            }
                        }
                    }
                    RowLayout { visible: !page.monthVisible; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 7
                        Repeater { model: backend.weekDays
                            delegate: Button { id: weekButton
                                Layout.fillWidth: true; Layout.preferredHeight: 90
                                text: modelData.label
                                background: Rectangle { color: selectedDate === modelData.date ? Theme.accentSoft : Theme.surfaceMuted;
                                    radius: 13; border.color: selectedDate === modelData.date ? Theme.accent : Theme.border }
                                contentItem: ColumnLayout { spacing: 4
                                    Text { text: modelData.label; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); Layout.alignment: Qt.AlignHCenter }
                                    Text { text: modelData.day; color: Theme.text; font.pixelSize: Math.max(11, Math.round(21 * backend.fontScale / 100)); font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: modelData.done + "/" + modelData.total; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); Layout.alignment: Qt.AlignHCenter }
                                }
                                onClicked: page.selectedDate = modelData.date
                            }
                        }
                    }
                }
            }
            RowLayout { Layout.fillWidth: true; spacing: 8
                Text { text: "Wybrana data:"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                FormInput { id: dateJump; text: page.selectedDate; Layout.preferredWidth: 155 }
                ActionButton { text: "Przejdź"; compact: true; primary: false; onClicked: {
                    if (backend.dateLabel(dateJump.text).length) page.selectedDate = dateJump.text
                    else page.statusMessage = "Niepoprawna data."
                } }
                Item { Layout.fillWidth: true }
                ActionButton { text: "Szybkie zadanie"; compact: true; primary: false; onClicked: {
                    quickTask.targetDate = page.selectedDate; quickTask.selectedMemberId = -1; quickTask.open()
                } }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: dayColumn.implicitHeight+35;
                color: Theme.surface; radius: 16; border.color: Theme.border
                ColumnLayout { id: dayColumn; anchors.fill: parent; anchors.margins: 18; spacing: 10
                    RowLayout { Layout.fillWidth: true
                        Text { text: backend.dateLabel(selectedDate); font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true;
                            color: Theme.text; Layout.fillWidth: true }
                        ActionButton { text: "Kopiuj dzień"; compact: true; primary: false; onClicked: {
                            copyDay.sourceDate = page.selectedDate; copyDay.open()
                        } }
                        ActionButton { text: "Szablon dnia"; compact: true; primary: false; onClicked: {
                            templateDialog.targetDate = page.selectedDate; templateDialog.open()
                        } }
                    }
                    Text { visible: page.entries.length === 0; text: "Brak zaplanowanych zadań. Możesz wstawić szablon dnia.";
                        color: Theme.muted; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    ListView { Layout.fillWidth: true; Layout.preferredHeight: Math.max(70, Math.min(580, page.entries.length*80));
                        model: page.entries; clip: true; spacing: 1; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: TaskRow { width: ListView.view ? ListView.view.width - 5 : 500; task: modelData
                            onCheckRequested: backend.setTaskDone(taskId, page.selectedDate, done)
                            onAssigneeRequested: { assignment.taskId=task.id; assignment.taskTitle=task.title;
                                assignment.currentMemberId=task.memberId; assignment.open() }
                            onActionRequested: { actions.task=task; actions.day=page.selectedDate; actions.open() }
                        }
                    }
                }
            }
            Text { text: page.statusMessage; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100));
                Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
    }
    Connections { target: backend; function onDataChanged() { page.entries = backend.tasksForDate(page.selectedDate); page.monthDays=backend.monthCalendar(page.monthAnchor) } }
    onSelectedDateChanged: { entries = backend.tasksForDate(selectedDate); dateJump.text = selectedDate }
    onMonthAnchorChanged: monthDays = backend.monthCalendar(monthAnchor)
    TaskEditor { id: editor; onSaved: page.statusMessage = "Zadanie zapisane." }
    QuickTaskPopup { id: quickTask }
    TaskActions { id: actions
        onEditRequested: { editor.taskId = taskId; editor.open() }
        onSubtasksRequested: { subtasks.taskId=taskId; subtasks.date=day; subtasks.open() }
        onAssignmentRequested: { assignment.taskId=taskId; assignment.taskTitle=actions.task.title;
            assignment.currentMemberId=actions.task.memberId; assignment.open() }
        onSuccess: page.statusMessage = message
    }
    AssignmentDialog { id: assignment }
    SubtasksDialog { id: subtasks }
    CopyDayDialog { id: copyDay; onCopied: page.statusMessage = message }
    DayTemplatesDialog { id: templateDialog }
    function newTask() { editor.taskId = -1; editor.initialDate = selectedDate; editor.open() }
}
