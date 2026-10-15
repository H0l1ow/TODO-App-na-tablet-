import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Item {
    id: root
    property var task: ({})
    property bool compactLayout: width < 560
    property bool showArchive: false
    property bool showCopy: false
    signal checkRequested(int taskId, bool done)
    signal archiveRequested(int taskId)
    signal assigneeRequested(int taskId)
    signal copyRequested(int taskId)
    signal actionRequested(int taskId)
    implicitHeight: 73

    RowLayout {
        anchors.fill: parent
        spacing: 9
        Rectangle {
            Layout.preferredWidth: 43; Layout.preferredHeight: 43
            radius: 11
            color: task.done ? Theme.accent : Theme.surfaceMuted
            border.width: 1
            border.color: task.done ? Theme.accent : Theme.border
            Text { anchors.centerIn: parent; text: task.done ? "\u2713" : task.skipped ? "\u2014" : "";
                font.pixelSize: 17; font.bold: true; color: task.done ? Theme.accentText : Theme.muted }
            MouseArea { anchors.fill: parent; onClicked: root.checkRequested(root.task.id, !root.task.done) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                Layout.fillWidth: true
                text: root.task.title || ""
                font.pixelSize: Math.max(14, Math.round(16 * backend.fontScale / 100))
                font.bold: !root.task.done
                font.strikeout: !!root.task.done
                color: root.task.done || root.task.skipped ? Theme.muted : Theme.text
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: (root.task.memberName || "Wszyscy")
                    + (root.task.dueTime ? "  \u00b7  " + root.task.dueTime : "")
                    + (root.task.skipped ? "  \u00b7  Pomini\u0119te" : "")
                    + (root.task.recurrence !== "once" ? "  \u00b7  Cykliczne" : "")
                font.pixelSize: 12
                color: root.task.skipped ? Theme.warning : Theme.muted
                elide: Text.ElideRight
            }
        }
        Button {
            id: personButton
            visible: !root.compactLayout
            Layout.preferredWidth: visible ? 106 : 0
            Layout.preferredHeight: 43
            text: task.memberName || "Wszyscy"
            background: Rectangle { color: Theme.accentSoft; radius: 10; border.color: Theme.border }
            contentItem: Text { text: personButton.text; color: Theme.accent;
                font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter;
                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            onClicked: root.assigneeRequested(root.task.id)
        }
        Button {
            id: moreButton
            Layout.preferredWidth: 43
            Layout.preferredHeight: 43
            text: "\u22ef"
            background: Rectangle { color: moreButton.down ? Theme.accentSoft : Theme.surfaceMuted;
                radius: 10; border.color: Theme.border }
            contentItem: Text { text: moreButton.text; color: Theme.text;
                font.pixelSize: 19; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: root.actionRequested(root.task.id)
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
