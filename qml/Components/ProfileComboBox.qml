import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window

/**
 * Profile picker using the default ComboBox popup with nested categories.
 * The delegate root is a plain Item (not an AbstractButton), so ComboBox's
 * internal select-and-close on click does not engage; clicks are handled
 * manually: headers expand/collapse, profile rows select and close. Collapsed
 * category rows are hidden via visible/height so indexes stay stable.
 */
ComboBox {
    id: control

    textRole: "name"
    model: []

    property int _expandedCategory: -1

    // Explicit popup pinned to the combo width. The stock select-and-close
    // machinery never engages (delegate roots are plain Items), so replacing
    // the popup does not affect the open/close behavior.
    popup: Popup {
        id: profilePopup

        y: control.height + 4
        width: control.width
        height: Math.min(listView.implicitHeight + 2 * padding, listView.maxHeight)
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        onClosed: control._expandedCategory = -1

        contentItem: ListView {
            id: listView

            property real maxHeight: Screen.desktopAvailableHeight - control.height - 24

            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0

            ScrollIndicator.vertical: ScrollIndicator {
            }
        }
    }

    function _headerIndexForRow(index) {
        for (var i = index; i >= 0; i--) {
            if (control.model[i] && control.model[i].isHeader)
                return i;
        }
        return -1;
    }

    delegate: Item {
        id: rowDelegate

        required property var modelData
        required property int index
        readonly property bool isHeader: !!modelData && modelData.isHeader
        readonly property int headerIndex: control._headerIndexForRow(index)

        TextMetrics {
            id: rowMetrics

            font: control.font
            text: rowDelegate.modelData ? rowDelegate.modelData.name : ""
        }

        // intrinsic width so popups that size from content width stay usable
        implicitWidth: rowMetrics.advanceWidth + 48
        implicitHeight: row.implicitHeight
        width: ListView.view ? ListView.view.width : implicitWidth
        visible: isHeader || control._expandedCategory === headerIndex
        height: visible ? implicitHeight : 0

        ItemDelegate {
            id: row

            width: parent.width
            text: rowDelegate.modelData ? rowDelegate.modelData.name : ""
            font.bold: rowDelegate.isHeader
            leftPadding: rowDelegate.isHeader ? 8 : 24
            highlighted: control.highlightedIndex === rowDelegate.index || (!control.popup.opened && control.currentIndex === rowDelegate.index && !rowDelegate.isHeader)

            contentItem: RowLayout {
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: rowDelegate.modelData ? rowDelegate.modelData.name : ""
                    font: row.font
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    visible: rowDelegate.isHeader
                    text: control._expandedCategory === rowDelegate.index ? "\u25BE" : "\u25B8"
                    verticalAlignment: Text.AlignVCenter
                }
            }

            onClicked: {
                if (rowDelegate.isHeader) {
                    control._expandedCategory = control._expandedCategory === rowDelegate.index ? -1 : rowDelegate.index;
                    return;
                }

                control.selectRow(rowDelegate.index);
                control.popup.close();
            }
        }
    }

    function selectRow(rowIndex) {
        var row = control.model[rowIndex];
        if (!row || row.isHeader)
            return;

        control.currentIndex = rowIndex;
    }

    function isHeaderRow(index) {
        return index >= 0 && index < control.count && !!control.model[index].isHeader
    }

    function indexOfProfile(name) {
        for (var i = 0; i < control.count; i++) {
            if (!control.model[i].isHeader && control.model[i].name === name)
                return i
        }
        return -1
    }

    function firstProfileIndex() {
        for (var i = 0; i < control.count; i++) {
            if (!control.model[i].isHeader)
                return i
        }
        return -1
    }
}
