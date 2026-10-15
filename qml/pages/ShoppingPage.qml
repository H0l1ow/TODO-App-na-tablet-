import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    property string info: ""
    property var catalog: backend.shoppingCatalog()
    property var setList: backend.shoppingSets()
    property string groupFilter: "Wszystkie"
    readonly property var groceryCategories: ["Podstawowe", "Nabiał", "Pieczywo", "Warzywa i owoce", "Mięso", "Chemia", "Inne"]
    property var products: backend.shoppingItems
    Connections { target: backend; function onDataChanged() {
        page.catalog=backend.shoppingCatalog(); page.setList=backend.shoppingSets()
    } }

    Flickable { anchors.fill: parent; clip: true; contentWidth: width; contentHeight: content.implicitHeight + 55
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout { id: content; x: 24; y: 20; width: parent.width-48; spacing: 16
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "Lista zakup\u00f3w"; font.pixelSize: 25; font.bold: true; color: Theme.text }
                RowLayout { Layout.fillWidth: true
                    Text { text: "Dodaj produkty jednym dotkni\u0119ciem."; Layout.fillWidth: true;
                        color: Theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap }
                    ActionButton { text: "Pon\u00f3w"; primary: false; compact: true;
                        onClicked: { var r=backend.repeatRecentShopping(7);
                            page.info = r.ok ? "Dodano " + r.added + " produkt\u00f3w." : "Brak zakup\u00f3w do ponowienia." } }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: quickContent.implicitHeight + 30;
                radius: 17; color: Theme.accentSoft; border.color: Theme.border
                ColumnLayout { id: quickContent; anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout { Layout.fillWidth: true
                        Text { text: "★  Szybkie produkty"; Layout.fillWidth: true;
                            color: Theme.accent; font.bold: true; font.pixelSize: Math.max(11, Math.round(16 * backend.fontScale / 100)) }
                        ActionButton { text: "Edytuj katalog"; compact: true; primary: false; onClicked: productDialog.open() }
                    }
                    Flow { Layout.fillWidth: true; Layout.preferredHeight: Math.max(56, childrenRect.height + 4);
                        spacing: 7
                        Repeater { model: Math.min(12,page.catalog.length)
                            delegate: ActionButton { text: "+ " + page.catalog[index].name; compact: true;
                                primary: false; implicitHeight: 50
                                onClicked: { if (!backend.addShoppingFromCatalog(page.catalog[index].id))
                                    page.info=backend.errorMessage }
                            }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: listContent.implicitHeight+38;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: listContent; anchors.fill: parent; anchors.margins: 18; spacing: 12
                    Text { text: "Dodaj własny produkt"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(18 * backend.fontScale / 100)); font.bold: true }
                    ColumnLayout { Layout.fillWidth: true; spacing: 8
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            FormInput { id: productInput; Layout.fillWidth: true; placeholderText: "Nazwa produktu";
                                maximumLength: 120; onAccepted: addProduct() }
                            FormInput { id: quantityInput; Layout.preferredWidth: 78;
                                placeholderText: "Ilo\u015b\u0107"; maximumLength: 40; onAccepted: addProduct() }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            ComboBox { id: categoryPicker; Layout.fillWidth: true; Layout.preferredHeight: 47;
                                model: page.groceryCategories }
                            ActionButton { text: "Dodaj"; onClicked: addProduct() }
                        }
                    }
                    CheckBox { id: rememberProduct; text: "Zapamiętaj produkt w katalogu"; checked: true; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                    ColumnLayout { Layout.fillWidth: true; spacing: 7
                        Text { text: "Do kupienia (" + backend.dashboard.shopping + ")";
                            font.pixelSize: 18; font.bold: true; color: Theme.text }
                        ComboBox { Layout.fillWidth: true; Layout.preferredHeight: 44;
                            model: ["Wszystkie"].concat(page.groceryCategories)
                            onCurrentTextChanged: page.groupFilter = currentText }
                    }
                    Text { text: "Lista jest pusta."; visible: page.products.length === 0;
                        Layout.fillWidth: true; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted }
                    ListView { Layout.fillWidth: true;
                        property var filtered: page.products.filter(function(p) { return page.groupFilter === "Wszystkie" || p.category === page.groupFilter })
                        Layout.preferredHeight: Math.max(80, Math.min(580, filtered.length*70))
                        clip: true; spacing: 3; model: filtered
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: ShoppingRow { width: ListView.view ? ListView.view.width - 5 : 500;
                            item: modelData; canRemove: true; canAdjust: true
                            onCheckRequested: backend.setShoppingDone(itemId, bought)
                            onRemoveRequested: backend.removeShoppingItem(itemId)
                            onQuantityRequested: backend.setShoppingQuantity(itemId, newQuantity) }
                    }
                    RowLayout { Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        ActionButton { text: "Usuń kupione"; compact: true; danger: true; primary: false;
                            enabled: page.products.length > backend.dashboard.shopping; onClicked: clearConfirm.open() }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: setsContent.implicitHeight+36;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: setsContent; anchors.fill: parent; anchors.margins: 17; spacing: 12
                    Text { text: "Zestawy zakupowe"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true }
                    ColumnLayout { Layout.fillWidth: true; spacing: 7
                        FormInput { id: setName; Layout.fillWidth: true;
                            placeholderText: "Np. Cotygodniowe zakupy"; maximumLength: 70 }
                        ActionButton { text: "Zapisz list\u0119 jako zestaw"; compact: true;
                            primary: false; Layout.fillWidth: true;
                            onClicked: { if (backend.saveShoppingSet(setName.text)) { page.info="Zapisano zestaw."; setName.clear() }
                                else page.info=backend.errorMessage } }
                    }
                    Repeater { model: page.setList
                        delegate: RowLayout { Layout.fillWidth: true
                            Text { text: modelData.name + " (" + modelData.count + " pozycji)";
                                Layout.fillWidth: true; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); color: Theme.text }
                            ActionButton { text: "Wstaw"; compact: true; onClicked: {
                                var r = backend.applyShoppingSet(modelData.id)
                                page.info = r.ok ? "Dodano " + r.added + " produktów." : "Nie można dodać zestawu."
                            } }
                            ActionButton { text: "Usuń"; danger: true; primary: false; compact: true;
                                onClicked: backend.deleteShoppingSet(modelData.id) }
                        }
                    }
                }
            }
            Text { text: page.info; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
    }
    function addProduct() {
        if (backend.addShoppingItem(productInput.text, quantityInput.text, categoryPicker.currentText)) {
            if (rememberProduct.checked)
                backend.saveCatalogProduct(productInput.text, categoryPicker.currentText, quantityInput.text, false)
            productInput.clear(); quantityInput.clear()
        }
    }
    Dialog { id: clearConfirm; title: "Usunąć zakupione produkty?"; modal: true;
        x: (page.width-width)/2; y: (page.height-height)/2; standardButtons: Dialog.Yes | Dialog.No
        onAccepted: backend.clearPurchased()
        contentItem: Text { text: "Pozycje znikną z bieżącej listy. Historia zakupów pozostanie.";
            width: 310; color: Theme.text; wrapMode: Text.WordWrap }
    }
    Dialog { id: productDialog; title: "Katalog szybkich produktów"; modal: true;
        width: Math.min(630,page.width-30); height: Math.min(580,page.height-25);
        x: (page.width-width)/2; y: (page.height-height)/2; standardButtons: Dialog.NoButton
        background: Rectangle { color: Theme.surface; radius: 17; border.color: Theme.border }
        contentItem: ColumnLayout { spacing: 10
            Text { text: "Dodaj lub zaktualizuj ulubiony produkt."; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
            ColumnLayout { Layout.fillWidth: true; spacing: 8
                RowLayout { Layout.fillWidth: true; spacing: 7
                    FormInput { id: catalogName; Layout.fillWidth: true; placeholderText: "Nazwa"; maximumLength: 120 }
                    FormInput { id: catalogQuantity; Layout.preferredWidth: 75; placeholderText: "Ilo\u015b\u0107"; maximumLength: 40 }
                }
                RowLayout { Layout.fillWidth: true; spacing: 7
                    ComboBox { id: catalogCategory; Layout.fillWidth: true; model: page.groceryCategories }
                    ActionButton { text: "Zapisz"; compact: true; onClicked: {
                        if (backend.saveCatalogProduct(catalogName.text,catalogCategory.currentText,catalogQuantity.text,true))
                            { catalogName.clear(); catalogQuantity.clear() }
                    } }
                }
            }
            ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: page.catalog; clip: true; spacing: 4
                delegate: RowLayout { width: ListView.view ? ListView.view.width-5 : 540; height: 50
                    Text { text: modelData.name + " · " + modelData.category;
                        Layout.fillWidth: true; color: Theme.text; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); elide: Text.ElideRight }
                    ActionButton { text: modelData.favorite ? "★" : "☆"; compact: true; primary: false;
                        onClicked: backend.toggleCatalogFavorite(modelData.id) }
                    ActionButton { text: "×"; compact: true; danger: true; primary: false;
                        onClicked: backend.deleteCatalogProduct(modelData.id) }
                }
            }
            ActionButton { Layout.fillWidth: true; text: "Gotowe"; primary: false; onClicked: productDialog.close() }
        }
    }
}
