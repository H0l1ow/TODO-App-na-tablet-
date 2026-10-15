import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

// Always-visible category and action lists; no radial geometry or animations.
Popup {
    id: root
    property string targetDate: backend.today
    property int selectedMemberId: -1
    property int categoryId: 0
    property var assigneeOptions: []
    property string statusMessage: ""
    property int addedCount: 0
    readonly property var categories: [{"id": 0, "name": "★ Najczęstsze", "symbol": "★"}].concat(backend.categories)
    property var templates: backend.quickTemplates(categoryId)
    onCategoryIdChanged: templates = backend.quickTemplates(categoryId)
    Connections { target: backend; function onDataChanged() { root.templates = backend.quickTemplates(root.categoryId) } }
    modal: true; dim: true; focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(830, (parent ? parent.width : 870) - 24)
    height: Math.min(650, (parent ? parent.height : 680) - 24)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    padding: 17
    background: Rectangle { radius: 19; color: Theme.surface; border.color: Theme.border }

    onOpened: {
        categoryId = 0; addedCount = 0; statusMessage = ""
        assigneeOptions = backend.assignees
        var idx = 0
        for (var i=0; i<assigneeOptions.length; ++i)
            if (assigneeOptions[i].id === selectedMemberId) idx = i
        quickAssignee.currentIndex = idx
        categoryList.positionViewAtBeginning()
        templateList.positionViewAtBeginning()
    }
    function addPreset(id, title) {
        var idx = quickAssignee.currentIndex
        var person = idx >= 0 && idx < assigneeOptions.length ? assigneeOptions[idx].id : -1
        if (backend.addFromQuickTemplate(id, targetDate, person)) {
            ++addedCount
            statusMessage = "✓ Dodano: " + title
        } else statusMessage = "Nie udało się dodać zadania."
    }
    contentItem: ColumnLayout {
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Szybkie zadania"; font.pixelSize: Math.max(11, Math.round(24 * backend.fontScale / 100)); font.bold: true; color: Theme.text; Layout.fillWidth: true }
            ActionButton { text: "Zamknij ×"; compact: true; primary: false; onClicked: root.close() }
        }
        Text { Layout.fillWidth: true; text: "Dotknij kategorii, a następnie gotowej czynności. Możesz dodać kilka zadań kolejno.";
               color: Theme.muted; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); wrapMode: Text.WordWrap }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
            Rectangle {
                Layout.preferredWidth: Math.min(225, Math.max(185, root.width * 0.28))
                Layout.fillHeight: true; radius: 14; color: Theme.surfaceMuted; border.color: Theme.border
                ListView {
                    id: categoryList; anchors.fill: parent; anchors.margins: 9; clip: true; spacing: 8
                    model: root.categories; boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Button {
                        id: categoryButton
                        width: ListView.view ? ListView.view.width - 8 : 180; height: 56
                        text: modelData.name
                        background: Rectangle { radius: 11; color: categoryButton.down || root.categoryId === modelData.id ? Theme.accentSoft : Theme.surface;
                            border.color: root.categoryId === modelData.id ? Theme.accent : Theme.border;
                            border.width: root.categoryId === modelData.id ? 2 : 1 }
                        contentItem: Text { text: modelData.symbol + "  " + categoryButton.text; color: Theme.text;
                            font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); font.bold: root.categoryId === modelData.id;
                            verticalAlignment: Text.AlignVCenter; leftPadding: 12; elide: Text.ElideRight }
                        onClicked: { root.categoryId = modelData.id; templateList.positionViewAtBeginning() }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 14; color: Theme.surface; border.color: Theme.border
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "Gotowe czynności"; font.pixelSize: Math.max(11, Math.round(18 * backend.fontScale / 100)); color: Theme.text; font.bold: true; Layout.fillWidth: true }
                    ListView {
                        id: templateList; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                        model: root.templates; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: RowLayout {
                            width: ListView.view ? ListView.view.width - 8 : 350; height: 58; spacing: 7
                            Button {
                                id: addButton
                                Layout.fillWidth: true; Layout.preferredHeight: 56
                                text: modelData.title
                                background: Rectangle { radius: 12; color: addButton.down ? Theme.accentSoft : Theme.surfaceMuted; border.color: Theme.border }
                                contentItem: Text { text: addButton.text + "  +"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(16 * backend.fontScale / 100));
                                    leftPadding: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                                onClicked: root.addPreset(modelData.id, modelData.title)
                            }
                            Button {
                                Layout.preferredWidth: 52; Layout.preferredHeight: 55
                                text: modelData.favorite ? "★" : "☆"
                                contentItem: Text { text: parent.text; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(23 * backend.fontScale / 100));
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 11; color: Theme.surfaceMuted; border.color: Theme.border }
                                onClicked: backend.toggleQuickFavorite(modelData.id)
                            }
                        }
                    }
                    Text { text: "Brak pozycji. Dodaj własne w zakładce Szablony."; visible: root.templates.length === 0;
                        font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Text { text: "Dla kogo?"; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted }
            ComboBox { id: quickAssignee; Layout.fillWidth: true; Layout.preferredHeight: 50;
                model: root.assigneeOptions; textRole: "name"; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)) }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.statusMessage; color: Theme.accent; Layout.fillWidth: true; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); elide: Text.ElideRight }
            ActionButton { text: "Gotowe (" + root.addedCount + ")"; onClicked: root.close() }
        }
    }
}
