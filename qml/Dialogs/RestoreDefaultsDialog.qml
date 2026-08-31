import "../Components" as Components
import QtQuick 2.15

Components.BaseConfirmDialog {
    id: root

    signal restoreRequested

    title: qsTr("Restore Default Profiles")
    bodyText: qsTr("This will reset all built-in profiles to their original settings.\n\nCustom profiles you created will not be affected.\n\nContinue?")
    onConfirmed: restoreRequested()
}
