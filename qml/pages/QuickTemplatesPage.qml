import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property int categoryId: backend.categories.length ? backend.categories[0].id : 0
    property var categoryRows: backend.categories
    property var taskRows: backend.quickTemplates(categoryId)
    property string feedback: ""
    Connections { target: backend
        function onDataChanged() { page.categoryRows = backend.categories; page.taskRows = backend.quickTemplates(page.categoryId) }
    }
    ColumnLayout { anchors.fill: parent; anchors.margins: 24; spacing: 14
        RowLayout { Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true
                Text { text: "Szybkie zadania i szablony"; font.pixelSize: Math.max(11, Math.round(27 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                Text { text: "Edytuj skróty dostępne w kuchennym panelu. Bez zmian w QML.";
                    color: Theme.muted; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
            }
            ActionButton { text: "+ Kategoria"; primary: false; onClicked: {
                categoryEditor.editId = -1; categoryEditor.open()
            } }
            ActionButton { text: "+ Czynność"; onClicked: {
                taskEditor.editId = -1; taskEditor.open()
            } }
        }
        RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
            Rectangle { Layout.preferredWidth: 235; Layout.fillHeight: true; color: Theme.surfaceMuted;
                border.color: Theme.border; radius: 16
                ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 12
                    Text { text: "KATEGORIE"; font.bold: true; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.muted }
                    ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: page.categoryRows; clip: true; spacing: 7
                        delegate: Button { id: b; width: ListView.view ? ListView.view.width-5 : 205; height: 60
                            text: modelData.name
                            background: Rectangle { radius: 11;
                                color: page.categoryId === modelData.id ? Theme.accentSoft : Theme.surface;
                                border.color: page.categoryId === modelData.id ? Theme.accent : Theme.border }
                            contentItem: Text { text: modelData.symbol+"  "+b.text; color: Theme.text;
                                font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); verticalAlignment: Text.AlignVCenter; leftPadding: 12 }
                            onClicked: { page.categoryId = modelData.id; page.taskRows = backend.quickTemplates(page.categoryId) }
                        }
                    }
                    ActionButton { text: "Zmień kategorię"; Layout.fillWidth: true; primary: false; compact: true;
                        enabled: page.categoryId > 0
                        onClicked: { categoryEditor.editId = page.categoryId; categoryEditor.open() } }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.surface;
                border.color: Theme.border; radius: 16
                ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 10
                    Text { text: "Czynności w kategorii"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true }
                    Text { text: "Gwiazdka dodaje czynność do ekranu Dzisiaj i listy Najczęstsze.";
                        font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: page.taskRows; clip: true; spacing: 7
                        delegate: Rectangle { width: ListView.view ? ListView.view.width-4 : 500; height: 66;
                            radius: 12; color: Theme.surfaceMuted; border.color: Theme.border
                            RowLayout { anchors.fill: parent; anchors.margins: 7; spacing: 9
                                Text { text: modelData.title; Layout.fillWidth: true; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100));
                                    color: Theme.text; elide: Text.ElideRight }
                                Text { text: modelData.uses + "×"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
                                ActionButton { text: modelData.favorite ? "★" : "☆"; compact: true; primary: false;
                                    onClicked: backend.toggleQuickFavorite(modelData.id) }
                                ActionButton { text: "Edytuj"; compact: true; primary: false;
                                    onClicked: { taskEditor.editId = modelData.id; taskEditor.open() } }
                            }
                        }
                    }
                    Text { text: page.taskRows.length === 0 ? "Brak zadań w kategorii. Dodaj pierwsze." : "";
                        color: Theme.muted; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
                }
            }
        }
        Text { text: feedback; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); Layout.fillWidth: true }
    }
    Dialog { id: categoryEditor; property int editId: -1; title: editId > 0 ? "Edytuj kategorię" : "Nowa kategoria"
        modal: true; width: 400; x: (page.width-width)/2; y: (page.height-height)/2;
        standardButtons: Dialog.NoButton; background: Rectangle { radius: 17; color: Theme.surface; border.color: Theme.border }
        onOpened: {
            var data = page.categoryRows.filter(function(c) { return c.id === editId })
            categoryName.text = data.length ? data[0].name : ""
            categorySymbol.text = data.length ? data[0].symbol : "★"
        }
        contentItem: ColumnLayout { spacing: 12
            Text { text: "Nazwa"; color: Theme.text }
            FormInput { id: categoryName; Layout.fillWidth: true; maximumLength: 42 }
            Text { text: "Symbol (np. ★, ✦)"; color: Theme.text }
            FormInput { id: categorySymbol; Layout.fillWidth: true; maximumLength: 5 }
            RowLayout {
                ActionButton { text: "Usuń"; danger: true; primary: false; visible: categoryEditor.editId > 0;
                    onClicked: { if (backend.deleteCategory(categoryEditor.editId)) { categoryEditor.close();
                        page.categoryId = backend.categories.length ? backend.categories[0].id : 0 } } }
                Item { Layout.fillWidth: true }
                ActionButton { text: "Anuluj"; primary: false; onClicked: categoryEditor.close() }
                ActionButton { text: "Zapisz"; onClicked: {
                    if (backend.saveCategory(categoryEditor.editId, categoryName.text, categorySymbol.text)) categoryEditor.close()
                    else page.feedback = backend.errorMessage
                } }
            }
        }
    }
    Dialog { id: taskEditor; property int editId: -1; title: editId > 0 ? "Edytuj szybkie zadanie" : "Nowe szybkie zadanie"
        modal: true; width: 480; x: (page.width-width)/2; y: (page.height-height)/2;
        standardButtons: Dialog.NoButton; background: Rectangle { radius: 17; color: Theme.surface; border.color: Theme.border }
        onOpened: {
            var all = page.taskRows.filter(function(t) { return t.id === editId })
            templateTitle.text = all.length ? all[0].title : ""
            favorite.checked = all.length ? all[0].favorite : false
            templateMember.currentIndex = 0
            templateCategory.currentIndex = 0
            var cats = backend.categories
            var current = all.length ? all[0].categoryId : page.categoryId
            for (var i=0; i<cats.length; ++i) if (cats[i].id === current) templateCategory.currentIndex = i
            var people = backend.assignees
            for (var j=0; j<people.length; ++j)
                if (all.length && people[j].id === all[0].memberId) templateMember.currentIndex = j
        }
        contentItem: ColumnLayout { spacing: 12
            Text { text: "Nazwa zadania"; color: Theme.text }
            FormInput { id: templateTitle; Layout.fillWidth: true; maximumLength: 160 }
            Text { text: "Kategoria"; color: Theme.text }
            ComboBox { id: templateCategory; Layout.fillWidth: true; Layout.preferredHeight: 50;
                model: backend.categories; textRole: "name" }
            Text { text: "Domyślny domownik"; color: Theme.text }
            ComboBox { id: templateMember; Layout.fillWidth: true; Layout.preferredHeight: 50;
                model: backend.assignees; textRole: "name" }
            CheckBox { id: favorite; text: "★ Ulubione na ekranie głównym"; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
            RowLayout { Layout.fillWidth: true
                ActionButton { text: "Usuń"; danger: true; primary: false; visible: taskEditor.editId > 0;
                    onClicked: { if (backend.deleteQuickTemplate(taskEditor.editId)) taskEditor.close() } }
                Item { Layout.fillWidth: true }
                ActionButton { text: "Anuluj"; primary: false; onClicked: taskEditor.close() }
                ActionButton { text: "Zapisz"; onClicked: {
                    var cats = backend.categories; var people = backend.assignees
                    if (cats.length && backend.saveQuickTemplate(taskEditor.editId, cats[templateCategory.currentIndex].id,
                            templateTitle.text, people[templateMember.currentIndex].id, favorite.checked)) taskEditor.close()
                    else page.feedback = backend.errorMessage || "Uzupełnij kategorię."
                } }
            }
        }
    }
}
