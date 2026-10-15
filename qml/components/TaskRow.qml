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
    signal actionRequested(int taskId)
    implicitHeight: 78

    RowLayout {
        anchors.fill: parent
        spacing: 9
        Rectangle {
            Layout.preferredWidth: 54; Layout.preferredHeight: 54
            radius: 13
            color: task.done ? Theme.accent : Theme.surfaceMuted
            border.width: 2; border.color: task.done ? Theme.accent : Theme.border
            Text { anchors.centerIn: parent; text: task.done ? "✓" : task.skipped ? "—" : "";
                   font.pixelSize: Math.max(11, Math.round(24 * backend.fontScale / 100)); font.bold: true; color: task.done ? Theme.accentText : Theme.muted }
            MouseArea { anchors.fill: parent; onClicked: root.checkRequested(task.id, !task.done) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                Layout.fillWidth: true
                text: root.task.title || ""
                font.pixelSize: Math.round(18 * backend.fontScale / 100)
                font.bold: !root.task.done
                font.strikeout: !!root.task.done
                color: root.task.done || root.task.skipped ? Theme.muted : Theme.text
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: (task.skipped ? "Pominięte" :
                    task.recurrence === "monthly" ? "↻ Co miesiąc" :
                    task.recurrence === "interval" ? "↻ Co " + task.intervalDays + " dni" :
                    task.recurrence === "daily" ? "↻ Codziennie" :
                    task.recurrence === "weekly" ? "↻ W wybrane dni" : "Jednorazowe")
                    + (task.categoryName ? " · " + task.categoryName : "")
                    + (task.dueTime ? " · " + task.dueTime : "")
                font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); color: task.skipped ? Theme.warning : Theme.muted
                elide: Text.ElideRight
            }
        }
        Button {
            id: personButton
            Layout.preferredWidth: root.width < 510 ? 90 : 122
            Layout.preferredHeight: 49
            text: task.memberName || "Wszyscy"
            background: Rectangle { color: Theme.accentSoft; radius: 11; border.color: Theme.border }
            contentItem: Text { text: personButton.text + " ▾"; horizontalAlignment: Text.AlignHCenter;
                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); font.bold: true }
            onClicked: root.assigneeRequested(task.id)
        }
        Button {
            id: moreButton
            Layout.preferredWidth: 50; Layout.preferredHeight: 49
            text: "⋯"
            background: Rectangle { color: moreButton.down ? Theme.accentSoft : Theme.surfaceMuted;
                radius: 11; border.color: Theme.border }
            contentItem: Text { text: moreButton.text; color: Theme.text;
                font.pixelSize: Math.max(11, Math.round(25 * backend.fontScale / 100)); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: root.actionRequested(task.id)
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
