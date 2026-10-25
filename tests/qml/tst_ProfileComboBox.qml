import "../../qml/Components"
import QtQuick
import QtQuick.Controls
import QtTest

TestCase {
    width: 200
    height: 200

    ProfileComboBox {
        id: combo

        model: [
            { "name": "General", "isHeader": true },
            { "name": "H.264 High", "isHeader": false },
            { "name": "AV1 High", "isHeader": false },
            { "name": "Custom", "isHeader": true },
            { "name": "Mine", "isHeader": false }
        ]
    }

    ProfileComboBox {
        id: replaced

        model: []
    }

    SpinBox {
        id: spin
    }

    function visibleRows() {
        // the Repeater itself is also a Column child — count rows only
        return combo.popup.contentItem.children.filter(function (c) {
            return c.visible && c.text !== undefined;
        });
    }

    function test_rowHelpers() {
        compare(combo.isHeaderRow(0), true);
        compare(combo.isHeaderRow(1), false);
        compare(combo.isHeaderRow(3), true);
        compare(combo.isHeaderRow(-1), false);
        compare(combo.isHeaderRow(combo.count), false);
        compare(combo.indexOfProfile("AV1 High"), 2);
        compare(combo.indexOfProfile("General"), -1);
        compare(combo.indexOfProfile("Missing"), -1);
        compare(combo.firstProfileIndex(), 1);
    }

    function test_textRoleResolvesRows() {
        combo.currentIndex = combo.indexOfProfile("H.264 High");
        compare(combo.currentText, "H.264 High");
    }

    function test_selectRowUpdatesCurrentText() {
        combo.selectRow(combo.indexOfProfile("AV1 High"));
        compare(combo.currentText, "AV1 High");
        combo.selectRow(0);
        compare(combo.currentText, "AV1 High");
    }

    function test_drilldownNavigation() {
        combo.popup.open();
        try {
            compare(combo.popup.opened, true);
            let rows = visibleRows();
            compare(rows.length, 2);
            compare(rows[0].text, "General");
            compare(rows[0].font.bold, true);
            // drill into a category
            rows[0].clicked();
            compare(combo._openCategory, 0);
            rows = visibleRows();
            compare(rows.length, 3);
            compare(rows[0].text, "\u2190 General");
            compare(rows[1].text, "H.264 High");
            compare(rows[2].text, "AV1 High");
            compare(rows[1].font.bold, false);
            // pick a profile: closes the popup and applies the selection
            rows[2].clicked();
            compare(combo.currentText, "AV1 High");
            compare(combo.popup.opened, false);
            compare(combo._openCategory, -1);
        } finally {
            combo.popup.close();
        }
    }

    function test_backNavigation() {
        combo.popup.open();
        try {
            visibleRows()[1].clicked();
            compare(combo._openCategory, 1);
            let rows = visibleRows();
            compare(rows.length, 2);
            compare(rows[0].text, "\u2190 Custom");
            rows[0].clicked();
            compare(combo._openCategory, -1);
            compare(visibleRows().length, 2);
        } finally {
            combo.popup.close();
        }
    }

    function test_popupCloseResetsDrilldown() {
        combo.popup.open();
        visibleRows()[0].clicked();
        combo.popup.close();
        compare(combo._openCategory, -1);
    }

    function test_outsideClickClosesPopup() {
        combo.popup.open();
        wait(50);
        mouseClick(spin);
        wait(50);
        compare(combo.popup.opened, false);
        compare(combo._openCategory, -1);
    }

    function test_modelReplacementKeepsHelpers() {
        replaced.model = [{
            "name": "Only",
            "isHeader": true
        }, {
            "name": "P",
            "isHeader": false
        }];
        compare(replaced.count, 2);
        compare(replaced.firstProfileIndex(), 1);
        compare(replaced.indexOfProfile("P"), 1);
        compare(replaced.isHeaderRow(0), true);
        compare(replaced.isHeaderRow(1), false);
        replaced.popup.open();
        try {
            const rows = replaced.popup.contentItem.children.filter(function (c) {
                return c.visible && c.text !== undefined;
            });
            compare(rows.length, 1);
            compare(rows[0].text, "Only");
        } finally {
            replaced.popup.close();
        }
    }
}
