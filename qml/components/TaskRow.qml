import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Item {
    id: root
    property var task: ({})
    property bool showArchive: false
    property bool showCopy: false
    signal checkRequested(int taskId, bool done)
    signal archiveRequested(int taskId)
    signal assigneeRequested(int taskId)
    signal copyRequested(int taskId)
    implicitHeight: 73

    RowLayout {
        anchors.fill: parent
        spacing: 8
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 9
            color: root.task.done ? Theme.accent : Theme.surface
            border.color: root.task.done ? Theme.accent : Theme.border
            border.width: 2
            Text {
                text: "✓"; anchors.centerIn: parent
                color: Theme.accentText; font.pixelSize: 18; font.bold: true
                visible: !!root.task.done
            }
            MouseArea { anchors.fill: parent; onClicked: root.checkRequested(root.task.id, !root.task.done) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: root.task.title || ""
                font.family: "Segoe UI"
                font.pixelSize: 15
                font.bold: !root.task.done
                font.strikeout: !!root.task.done
                color: root.task.done ? Theme.muted : Theme.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: root.task.recurrence === "daily" ? "↻ Codziennie" : root.task.recurrence === "weekly" ? "↻ Co tydzień" : "Jednorazowe"
                font.pixelSize: 11
                color: Theme.muted
                Layout.fillWidth: true
            }
        }
        Button {
            id: personButton
            Layout.preferredWidth: root.width < 500 ? 84 : 112
            Layout.preferredHeight: 38
            ToolTip.visible: hovered
            ToolTip.text: "Zmień osobę przypisaną do zadania"
            background: Rectangle { radius: 12; color: Theme.accentSoft; border.color: Theme.border }
            contentItem: Text {
                text: (root.task.memberName || "Wszyscy") + " ▾"
                color: Theme.accent
                font.pixelSize: 12; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: root.assigneeRequested(root.task.id)
        }
        Button {
            id: nextButton
            visible: root.showCopy
            Layout.preferredWidth: 77
            Layout.preferredHeight: 38
            ToolTip.visible: hovered
            ToolTip.text: "Kopiuj to zadanie na następny dzień"
            background: Rectangle { radius: 12; color: Theme.surfaceMuted; border.color: Theme.border }
            contentItem: Text {
                text: "→ Jutro"
                color: Theme.text
                font.pixelSize: 12; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.copyRequested(root.task.id)
        }
        Button {
            visible: root.showArchive
            Layout.preferredWidth: 31; Layout.preferredHeight: 38
            ToolTip.visible: hovered
            ToolTip.text: "Archiwizuj zadanie"
            background: Rectangle { color: "transparent"; radius: 7 }
            contentItem: Text { text: "×"; color: Theme.muted; font.pixelSize: 23; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: root.archiveRequested(root.task.id)
        }
    }
    Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Theme.border }
}
