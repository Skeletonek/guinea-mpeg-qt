import "../../qml/Components"
import QtQuick
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

    function _collectDelegates(item, out) {
        for (let i = 0; i < item.children.length; i++) {
            let child = item.children[i];
            if (child.index !== undefined)
                out.push(child);
            _collectDelegates(child, out);
        }
    }

    function delegateAt(comboObj, index) {
        let dels = [];
        _collectDelegates(comboObj.popup.contentItem, dels);
        return dels.length > index ? dels[index] : null;
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

    function test_headerIndexForRow() {
        compare(combo._headerIndexForRow(1), 0);
        compare(combo._headerIndexForRow(2), 0);
        compare(combo._headerIndexForRow(4), 3);
        compare(combo._headerIndexForRow(-1), -1);
    }

    function test_selectRowUpdatesCurrentText() {
        combo.selectRow(combo.indexOfProfile("AV1 High"));
        compare(combo.currentText, "AV1 High");
        combo.selectRow(0);
        compare(combo.currentText, "AV1 High");
    }

    function test_headerClickExpandsWithoutClosing() {
        // reset expansion from earlier tests, then put the list at the top
        // (row 0 is the header) so no auto-scroll can push it out of view
        combo._expandedCategory = -1;
        combo.currentIndex = 0;
        combo.popup.open();
        wait(50);
        try {
            compare(combo.popup.opened, true);
            let head = delegateAt(combo, 0);
            verify(head);
            mouseClick(head);
            wait(50);
            // expanding a category must not close the popup
            compare(combo.popup.opened, true);
            compare(combo._expandedCategory, 0);
            // clicking it again collapses
            mouseClick(head);
            wait(50);
            compare(combo._expandedCategory, -1);
            compare(combo.popup.opened, true);
            // expand again for the child-row test
            mouseClick(head);
            wait(50);
            compare(combo._expandedCategory, 0);
        } finally {
            combo.popup.close();
        }
    }

    function test_childClickSelectsAndCloses() {
        // put the list at the top, expand row 0, then click its first child
        combo.currentIndex = 0;
        combo.popup.open();
        wait(50);
        try {
            let head = delegateAt(combo, 0);
            verify(head);
            mouseClick(head);
            wait(50);
            compare(combo._expandedCategory, 0);
            // child rows of row 0 are popup items 1 and 2
            let kid = delegateAt(combo, 1);
            verify(kid);
            mouseClick(kid);
            wait(50);
            compare(combo.popup.opened, false);
            compare(combo.currentIndex, 1);
            compare(combo.currentText, "H.264 High");
        } finally {
            combo.popup.close();
        }
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
    }
}
