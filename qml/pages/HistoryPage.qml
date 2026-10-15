import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property string selectedDate: backend.today
    property int memberFilter: -2
    property int rangeDays: 14
    property var chartDays: backend.historyForRange(rangeDays, memberFilter)
    property var dayEntries: backend.historyForDay(selectedDate,memberFilter)
    property var stats: backend.historyStats
    property string exportMessage: ""
    Connections { target: backend; function onDataChanged() { refresh() } }
    onMemberFilterChanged: refresh()
    onRangeDaysChanged: refresh()
    onSelectedDateChanged: dayEntries = backend.historyForDay(selectedDate, memberFilter)
    function refresh() { chartDays = backend.historyForRange(rangeDays,memberFilter);
        dayEntries = backend.historyForDay(selectedDate,memberFilter) }

    Flickable { id: scroll; anchors.fill: parent; clip: true; contentWidth: width;
        contentHeight: content.implicitHeight + 46; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout { id: content; x: 24; y: 20; width: scroll.width - 48; spacing: 17
            RowLayout { Layout.fillWidth: true
                ColumnLayout { Layout.fillWidth: true
                    Text { text: "Historia i statystyki"; font.pixelSize: Math.max(11, Math.round(30 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                    Text { text: "Dni bez zaplanowanych zadań oznaczamy jako „Brak planu”, nie 0%.";
                        color: Theme.muted; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
                }
                ActionButton { text: "Eksport CSV"; primary: false; onClicked: {
                    var file = backend.exportHistoryCsv("")
                    page.exportMessage = file ? "Wyeksportowano: "+file : backend.errorMessage
                } }
            }
            RowLayout { Layout.fillWidth: true; spacing: 12
                StatCard { Layout.fillWidth: true; caption: "Wykonane w 7 dni"; amount: ""+stats.done7; note: "ostatni tydzień" }
                StatCard { Layout.fillWidth: true; caption: "Wykonane w 30 dni"; amount: ""+stats.done30; note: "ostatni miesiąc" }
                StatCard { Layout.fillWidth: true; caption: "Skuteczność"; amount: stats.percent7 < 0 ? "—" : stats.percent7+"%";
                    note: stats.planned7+" zaplanowanych w 7 dni" }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: chartContent.implicitHeight + 35;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: chartContent; anchors.fill: parent; anchors.margins: 17; spacing: 10
                    RowLayout { Layout.fillWidth: true
                        Text { text: "Postęp dzienny"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text; Layout.fillWidth: true }
                        ComboBox { id: period; Layout.preferredWidth: 155; model: ["14 dni", "30 dni"];
                            onCurrentIndexChanged: page.rangeDays = currentIndex === 0 ? 14 : 30 }
                        ComboBox { id: member; Layout.preferredWidth: 185;
                            model: [{"id": -2,"name":"Wszyscy"}].concat(backend.assignees); textRole: "name"
                            onCurrentIndexChanged: {
                                var all = [{"id": -2,"name":"Wszyscy"}].concat(backend.assignees)
                                page.memberFilter = all[Math.max(0,currentIndex)].id
                            } }
                    }
                    Repeater { model: page.chartDays
                        delegate: RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 24; spacing: 11
                            Text { text: modelData.label; Layout.preferredWidth: 86; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); color: Theme.muted }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 11; radius: 6; color: Theme.surfaceMuted
                                Rectangle { width: modelData.percent < 0 ? 0 : parent.width * modelData.percent/100;
                                    height: parent.height; radius: 6; color: Theme.accent }
                            }
                            Text { text: modelData.planned === 0 ? "Brak planu" : modelData.done+" / "+modelData.planned;
                                Layout.preferredWidth: 85; horizontalAlignment: Text.AlignRight;
                                font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); color: Theme.text }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: detailColumn.implicitHeight + 38;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: detailColumn; anchors.fill: parent; anchors.margins: 18; spacing: 11
                    RowLayout { Layout.fillWidth: true
                        Text { text: "Historia konkretnego dnia"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text;
                            Layout.fillWidth: true }
                        FormInput { id: dayInput; Layout.preferredWidth: 170; text: page.selectedDate }
                        ActionButton { text: "Pokaż"; compact: true; primary: false; onClicked: {
                            if (backend.dateLabel(dayInput.text).length) page.selectedDate = dayInput.text
                        } }
                    }
                    Text { text: backend.dateLabel(page.selectedDate); font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted }
                    Text { text: "Brak zaplanowanych zadań w tym dniu."; visible: page.dayEntries.length === 0;
                        font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted }
                    Repeater { model: page.dayEntries
                        delegate: RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 48; spacing: 10
                            Text { text: modelData.done ? "✓" : modelData.skipped ? "—" : "○";
                                font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); color: modelData.done ? Theme.accent : modelData.skipped ? Theme.warning : Theme.muted }
                            Text { text: modelData.title; Layout.fillWidth: true; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100));
                                color: Theme.text; elide: Text.ElideRight }
                            Text { text: modelData.memberName || "Wszyscy"; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); color: Theme.muted }
                            Text { text: modelData.doneByName || modelData.status; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); color: Theme.muted }
                        }
                    }
                }
            }
            Text { text: page.exportMessage; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100));
                wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
        }
    }
}
