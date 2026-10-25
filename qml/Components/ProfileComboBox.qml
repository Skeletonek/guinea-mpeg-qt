import QtQuick
import QtQuick.Controls 2.15

/**
 * Profile picker: click a category to drill into its profiles ("← name" goes
 * back). Single in-scene popup, so no native menu surface quirks.
 * Model: flat rows ({name, isHeader}) from DataUtils.profileRows().
 */
ComboBox {
    id: control

    textRole: "name"
    model: []

    readonly property var _groups: _regroup()
    property int _openCategory: -1

    function _regroup() {
        var groups = [];
        var current = null;
        for (var i = 0; i < control.model.length; i++) {
            var row = control.model[i];
            if (row.isHeader) {
                current = {
                    "category": row.name,
                    "names": [],
                    "startIndex": i + 1
                };
                groups.push(current);
            } else if (current) {
                current.names.push(row.name);
            }
        }
        return groups;
    }

    popup: Popup {
        id: profilePopup

        y: control.height + 4
        width: Math.max(control.width, implicitWidth)
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        // outside presses land on this (dialog-style overlay catcher): SpinBox
        // etc. would otherwise swallow the press and keep the popup open
        Overlay.modal: MouseArea {
            onClicked: profilePopup.close()
        }
        onClosed: control._openCategory = -1

        contentItem: Column {
            id: popupColumn

            spacing: 0

            ItemDelegate {
                visible: control._openCategory >= 0
                width: parent.width
                font.bold: true
                text: control._openCategory >= 0 ? "\u2190 " + control._groups[control._openCategory].category : ""
                onClicked: control._openCategory = -1
            }

            Repeater {
                model: control._openCategory >= 0 ? control._groups[control._openCategory].names : control._groups

                delegate: ItemDelegate {
                    required property var modelData
                    required property int index

                    width: parent.width
                    font.bold: control._openCategory < 0
                    text: control._openCategory >= 0 ? modelData : modelData.category
                    onClicked: {
                        if (control._openCategory >= 0) {
                            control.selectRow(control._groups[control._openCategory].startIndex + index);
                            profilePopup.close();
                        } else {
                            control._openCategory = index;
                        }
                    }
                }
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
