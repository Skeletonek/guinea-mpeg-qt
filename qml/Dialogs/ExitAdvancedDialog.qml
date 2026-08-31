import "../Components" as Components
import QtQuick 2.15

Components.BaseConfirmDialog {
    id: root

    signal exitRequested

    title: qsTr("Exit Advanced Mode")
    bodyText: qsTr("Exiting advanced mode will erase your custom ffmpeg command and return to standard profile editing.\n\nYour other profile settings are kept.\n\nContinue?")
    onConfirmed: exitRequested()
}
