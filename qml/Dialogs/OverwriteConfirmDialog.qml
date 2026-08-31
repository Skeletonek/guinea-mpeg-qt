import "../Components" as Components
import "../Utils/Centering.js" as Utils
import QtQuick 2.15

Components.BaseConfirmDialog {
    id: root

    property string filePath: ""

    signal overwriteRequested

    title: qsTr("Overwrite File")
    bodyText: qsTr("The output file already exists:\n\n\"%1\"\n\nDo you want to overwrite it?").arg(root.filePath)
    onConfirmed: overwriteRequested()
    onOpened: {
        Utils.centerInParent(root);
        backend.systemBeep();
    }
}
