import "../Components" as Components
import "../Utils/Constants.js" as Constants
import QtQuick 2.15

Components.BaseConfirmDialog {
    id: root

    property string profileName: ""

    signal deleteRequested

    title: qsTr("Delete Profile")
    width: Constants.dialogWidthSmall
    bodyText: qsTr("Delete profile \"%1\"?\n\nThis cannot be undone.").arg(root.profileName)
    onConfirmed: deleteRequested()
}
