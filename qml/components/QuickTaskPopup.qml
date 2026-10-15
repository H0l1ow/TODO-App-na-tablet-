import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

// Portrait friendly: compact, horizontally scrollable categories and a single list.
Popup {
    id: root
    property string targetDate: backend.today
    property int selectedMemberId: -1
    property int categoryId: 0
    property var assigneeOptions: []
    property string statusMessage: ""
    property int addedCount: 0
    readonly property var categories: [{"id": 0, "name": "Najcz\u0119stsze", "symbol": "\u2606"}].concat(backend.categories)
    property var templates: backend.quickTemplates(categoryId)
    onCategoryIdChanged: templates = backend.quickTemplates(categoryId)
    Connections { target: backend; function onDataChanged() { root.templates = backend.quickTemplates(root.categoryId) } }
    modal: true; dim: true; focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(620, (parent ? parent.width : 680) - 20)
    height: Math.min(690, (parent ? parent.height : 730) - 20)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    padding: 14
    background: Rectangle { radius: 16; color: Theme.surface; border.color: Theme.border }

    onOpened: {
        categoryId = 0
        addedCount = 0
        statusMessage = ""
        assigneeOptions = backend.assignees
        var index = 0
        for (var i = 0; i < assigneeOptions.length; ++i)
            if (assigneeOptions[i].id === selectedMemberId) index = i
        quickAssignee.currentIndex = index
        categoryList.positionViewAtBeginning()
        templateList.positionViewAtBeginning()
    }
    function addPreset(id, title) {
        var index = quickAssignee.currentIndex
        var person = index >= 0 && index < assigneeOptions.length ? assigneeOptions[index].id : -1
        if (backend.addFromQuickTemplate(id, targetDate, person)) {
            ++addedCount
            statusMessage = "Dodano: " + title
        } else statusMessage = backend.errorMessage || "Nie uda\u0142o si\u0119 doda\u0107 zadania."
    }

    contentItem: ColumnLayout {
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Szybkie zadania"; color: Theme.text;
                font.bold: true; font.pixelSize: 20; Layout.fillWidth: true }
            ActionButton { text: "Zamknij"; compact: true; primary: false; onClicked: root.close() }
        }
        Text { text: "1. Wybierz kategori\u0119"; color: Theme.muted; font.pixelSize: 13 }
        ListView {
            id: categoryList
            Layout.fillWidth: true
            Layout.preferredHeight: 49
            orientation: ListView.Horizontal
            clip: true
            spacing: 7
            model: root.categories
            boundsBehavior: Flickable.StopAtBounds
            delegate: Button {
                id: categoryButton
                width: Math.max(116, Math.min(156, categoryLabel.implicitWidth + 23))
                height: 46
                background: Rectangle {
                    radius: 10
                    color: root.categoryId === modelData.id ? Theme.accentSoft : Theme.surfaceMuted
                    border.color: root.categoryId === modelData.id ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    id: categoryLabel
                    text: modelData.name
                    font.pixelSize: 13
                    font.bold: root.categoryId === modelData.id
                    color: Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                onClicked: { root.categoryId = modelData.id; templateList.positionViewAtBeginning() }
            }
        }
        Text { text: "2. Dotknij zadania"; color: Theme.muted; font.pixelSize: 13 }
        ListView {
            id: templateList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: root.templates
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: RowLayout {
                width: ListView.view ? ListView.view.width - 5 : 350
                height: 54
                spacing: 7
                Button {
                    id: addButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    text: modelData.title
                    background: Rectangle { color: addButton.down ? Theme.accentSoft : Theme.surfaceMuted;
                        border.color: Theme.border; radius: 10 }
                    contentItem: RowLayout {
                        spacing: 9
                        Text { text: addButton.text; Layout.fillWidth: true;
                            color: Theme.text; font.pixelSize: 15; elide: Text.ElideRight }
                        Text { text: "+"; color: Theme.accent; font.pixelSize: 17; font.bold: true }
                    }
                    onClicked: root.addPreset(modelData.id, modelData.title)
                }
                Button {
                    id: favoriteButton
                    Layout.preferredWidth: 45
                    Layout.preferredHeight: 52
                    text: modelData.favorite ? "\u2605" : "\u2606"
                    background: Rectangle { radius: 10; color: Theme.surfaceMuted; border.color: Theme.border }
                    contentItem: Text { text: favoriteButton.text; font.pixelSize: 17;
                        color: Theme.accent; horizontalAlignment: Text.AlignHCenter;
                        verticalAlignment: Text.AlignVCenter }
                    onClicked: backend.toggleQuickFavorite(modelData.id)
                }
            }
        }
        Text { text: "Brak czynno\u015bci w tej kategorii."; visible: root.templates.length === 0;
            color: Theme.muted; font.pixelSize: 14; Layout.fillWidth: true }
        Text { text: "Przypisz do:"; color: Theme.muted; font.pixelSize: 13 }
        ComboBox { id: quickAssignee; Layout.fillWidth: true; Layout.preferredHeight: 45;
            model: root.assigneeOptions; textRole: "name"; font.pixelSize: 14 }
        Text { text: root.statusMessage; Layout.fillWidth: true; color: Theme.accent;
            font.pixelSize: 13; elide: Text.ElideRight }
        ActionButton { text: "Gotowe (" + root.addedCount + ")"; Layout.fillWidth: true;
            onClicked: root.close() }
    }
}
