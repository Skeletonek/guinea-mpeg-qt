import "../Components" as Components
import "../Utils/Centering.js" as Utils
import QtQuick 2.15

Components.BaseConfirmDialog {
    id: root

    property int batchCount: 0

    title: qsTr("Cut All Loaded Files")
    bodyText: qsTr("Using the timeline selection will cut all %1 loaded files to this length.\n\nShorter files will be cut at their maximum length.\n\nContinue?").arg(root.batchCount)
    onOpened: {
        Utils.centerInParent(root);
        backend.systemBeep();
    }
}
