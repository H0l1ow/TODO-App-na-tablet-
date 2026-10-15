import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    readonly property var stats: backend.historyStats
    Flickable {
        id: scroll; anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.height + 50
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content; x: 26; y: 26; width: scroll.width - 52; spacing: 20
            Text { text: "Historia i statystyki"; font.pixelSize: 30; font.bold: true; color: Theme.text }
            Text { text: "Zadania ukończone na tym tablecie. Postęp dla dni bez zadań wynosi 0%."; font.pixelSize: 14; color: Theme.muted; wrapMode: Text.WordWrap; width: parent.width }
            Row {
                width: parent.width; height: 126; spacing: 14
                StatCard { width: (parent.width - 28)/3; caption: "Ostatnie 7 dni"; amount: "" + stats.done7; note: "Wykonanych" }
                StatCard { width: (parent.width - 28)/3; caption: "Ostatnie 30 dni"; amount: "" + stats.done30; note: "Wykonanych" }
                StatCard { width: (parent.width - 28)/3; caption: "Skuteczność 7 dni"; amount: stats.percent7 + "%"; note: stats.planned7 + " zaplanowanych" }
            }
            Rectangle {
                width: parent.width; height: chartContent.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: chartContent; x: 20; y: 20; width: parent.width - 40; spacing: 13
                    Text { text: "Ostatnie 14 dni"; font.pixelSize: 20; font.bold: true; color: Theme.text }
                    Repeater {
                        model: backend.historyDays
                        delegate: RowLayout {
                            width: chartContent.width; height: 24; spacing: 12
                            Text { text: modelData.label; Layout.preferredWidth: 94; font.pixelSize: 12; color: Theme.muted }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 11; radius: 6
                                color: Theme.surfaceMuted
                                Rectangle { width: parent.width * modelData.percent/100; height: parent.height; radius: 6; color: Theme.accent }
                            }
                            Text {
                                text: modelData.done + " / " + modelData.planned
                                Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight
                                font.pixelSize: 12; color: Theme.text
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: recentColumn.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: recentColumn; x: 20; y: 20; width: parent.width - 40; spacing: 9
                    Text { text: "Ostatnio wykonane"; font.pixelSize: 20; font.bold: true; color: Theme.text }
                    Text { text: "Brak wykonanych zadań."; visible: backend.recentActivity.length === 0; color: Theme.muted; font.pixelSize: 14; topPadding: 10; bottomPadding: 10 }
                    Repeater {
                        model: backend.recentActivity
                        delegate: Item {
                            width: recentColumn.width; height: 51
                            RowLayout {
                                anchors.fill: parent; spacing: 10
                                Text { text: "✓"; font.bold: true; font.pixelSize: 17; color: Theme.accent }
                                Text { text: modelData.title; Layout.fillWidth: true; font.pixelSize: 14; color: Theme.text; elide: Text.ElideRight }
                                Text { text: modelData.day; font.pixelSize: 12; color: Theme.muted }
                                Text { text: modelData.memberName; font.pixelSize: 12; color: Theme.muted; visible: !!modelData.memberName }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                        }
                    }
                }
            }
        }
    }
}
