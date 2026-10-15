import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property int pendingDelete: -1
    property int expandedMember: -1
    property string feedback: ""
    Flickable { anchors.fill: parent; clip: true; contentWidth: width;
        contentHeight: content.implicitHeight + 48;
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout { id: content; x: 24; y: 22; width: parent.width-48; spacing: 16
            Text { text: "Domownicy"; font.pixelSize: Math.max(11, Math.round(30 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
            Text { text: "Lokalne profile bez logowania. „Wszyscy” oznacza jeden wspólny obowiązek.";
                font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: editorRow.implicitHeight+36;
                radius: 16; color: Theme.surface; border.color: Theme.border
                RowLayout { id: editorRow; anchors.fill: parent; anchors.margins: 16; spacing: 10
                    FormInput { id: memberName; Layout.fillWidth: true; maximumLength: 48; placeholderText: "Imię domownika";
                        onAccepted: addPerson() }
                    ActionButton { text: "+ Dodaj domownika"; onClicked: addPerson() }
                }
            }
            Repeater { model: backend.members
                delegate: Rectangle { Layout.fillWidth: true;
                    Layout.preferredHeight: memberContent.implicitHeight+32;
                    radius: 16; color: Theme.surface; border.color: Theme.border
                    ColumnLayout { id: memberContent; anchors.fill: parent; anchors.margins: 15; spacing: 10
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            Rectangle { Layout.preferredWidth: 53; Layout.preferredHeight: 53; radius: 26;
                                color: modelData.color
                                Text { anchors.centerIn: parent; text: modelData.initial;
                                    color: "#365446"; font.pixelSize: Math.max(11, Math.round(24 * backend.fontScale / 100)); font.bold: true }
                            }
                            ColumnLayout { Layout.fillWidth: true; spacing: 4
                                Text { text: modelData.name; color: Theme.text; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true }
                                Text { text: modelData.remaining + " do zrobienia · " + modelData.done + " ukończonych";
                                    color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                            }
                            ActionButton { text: page.expandedMember === modelData.id ? "Zwiń" : "Pokaż zadania";
                                compact: true; primary: false; onClicked: page.expandedMember =
                                    page.expandedMember === modelData.id ? -1 : modelData.id }
                            ActionButton { text: "Usuń"; compact: true; danger: true; primary: false;
                                onClicked: { page.pendingDelete=modelData.id; confirmDelete.open() } }
                        }
                        ColumnLayout { Layout.fillWidth: true; spacing: 4;
                            visible: page.expandedMember === modelData.id
                            Repeater { model: backend.tasksForDateFiltered(backend.today,modelData.id)
                                delegate: RowLayout { Layout.fillWidth: true
                                    Text { text: modelData.done ? "✓" : "□"; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(19 * backend.fontScale / 100)) }
                                    Text { text: modelData.title; Layout.fillWidth: true; color: Theme.text;
                                        font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); elide: Text.ElideRight }
                                    ActionButton { text: "Dla wszystkich"; primary: false; compact: true;
                                        onClicked: backend.setTaskAssignee(modelData.id,-1) }
                                }
                            }
                        }
                    }
                }
            }
            Text { text: "Brak domowników. Nadal możesz dodawać obowiązki wspólne.";
                color: Theme.muted; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); visible: backend.members.length === 0 }
            Text { text: page.feedback; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.accent; Layout.fillWidth: true }
        }
    }
    function addPerson() { if (backend.addMember(memberName.text)) memberName.clear() }
    Dialog { id: confirmDelete; title: "Usunąć domownika?"; modal: true;
        x: (page.width-width)/2; y: (page.height-height)/2;
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: backend.removeMember(page.pendingDelete)
        contentItem: Text { width: 310; wrapMode: Text.WordWrap; color: Theme.text;
            text: "Przypisane zadania staną się wspólne. Historia wykonania pozostanie w bazie." }
    }
}
