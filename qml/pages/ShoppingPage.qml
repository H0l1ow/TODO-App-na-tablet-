import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    Flickable {
        id: scroll; anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.height + 42
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content; x: 26; y: 26; width: scroll.width - 52; spacing: 18
            Text { text: "Lista zakupów"; font.pixelSize: 30; font.bold: true; color: Theme.text }
            Text { text: "Wpisz produkt i ilość. Dotknij kwadratu, gdy produkt trafi do koszyka."; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Rectangle {
                width: parent.width; height: buyContent.implicitHeight + 40
                radius: 18; color: Theme.surface; border.color: Theme.border
                Column {
                    id: buyContent; x: 20; y: 20; width: parent.width - 40; spacing: 13
                    RowLayout {
                        width: parent.width; spacing: 10
                        FormInput {
                            id: productName; Layout.fillWidth: true
                            placeholderText: "Np. Mleko"; maximumLength: 120
                            onAccepted: addProduct()
                        }
                        FormInput {
                            id: productQuantity
                            Layout.preferredWidth: 130
                            placeholderText: "Ilość"; maximumLength: 40
                            onAccepted: addProduct()
                        }
                        ActionButton { text: "+ Dodaj"; onClicked: addProduct() }
                    }
                    RowLayout {
                        width: parent.width; height: 36
                        Text { text: "Produkty"; font.pixelSize: 19; font.bold: true; color: Theme.text; Layout.fillWidth: true }
                        Text { text: backend.dashboard.shopping + " do kupienia"; font.pixelSize: 12; color: Theme.muted }
                    }
                    Text { text: "Lista jest pusta. Dodaj pierwszy produkt."; visible: backend.shoppingItems.length === 0; color: Theme.muted; font.pixelSize: 14; topPadding: 16; bottomPadding: 18 }
                    Repeater {
                        model: backend.shoppingItems
                        delegate: ShoppingRow {
                            width: buyContent.width
                            item: modelData
                            canRemove: true
                            onCheckRequested: backend.setShoppingDone(itemId, bought)
                            onRemoveRequested: backend.removeShoppingItem(itemId)
                        }
                    }
                    RowLayout {
                        width: parent.width; height: 47
                        Item { Layout.fillWidth: true }
                        ActionButton {
                            text: "Usuń kupione"; primary: false; compact: true
                            enabled: backend.shoppingItems.length > backend.dashboard.shopping
                            onClicked: clearPopup.open()
                        }
                    }
                }
            }
        }
    }
    function addProduct() {
        if (backend.addShoppingItem(productName.text, productQuantity.text)) {
            productName.clear(); productQuantity.clear(); productName.forceActiveFocus()
        }
    }
    Dialog {
        id: clearPopup
        title: "Wyczyścić zakupione?"
        modal: true; x: (page.width-width)/2; y: (page.height-height)/2
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: backend.clearPurchased()
        contentItem: Text { text: "Kupione pozycje zostaną usunięte z listy."; color: Theme.text; width: 300; wrapMode: Text.WordWrap; topPadding: 12; bottomPadding: 12 }
    }
}
