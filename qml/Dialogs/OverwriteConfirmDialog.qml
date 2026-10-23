import "../Components" as Components
import "../Utils/Centering.js" as Utils
import QtQuick 2.15

Components.BaseConfirmDialog {
    id: root

    property var filePaths: []

    function _bodyText() {
        var files = filePaths || [];
        if (files.length === 1)
            return qsTr("The output file already exists:\n\n\"%1\"\n\nDo you want to overwrite it?").arg(files[0]);
        var list = "";
        for (var i = 0; i < files.length; i++)
            list += "\"" + files[i] + "\"\n";
        return qsTr("The following %1 output files already exist:\n\n%2\nDo you want to overwrite them?").arg(files.length).arg(list);
    }

    signal overwriteRequested

    title: qsTr("Overwrite File")
    bodyText: root._bodyText()
    onConfirmed: overwriteRequested()
    onOpened: {
        Utils.centerInParent(root);
        backend.systemBeep();
    }
}
