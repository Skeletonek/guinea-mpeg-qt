import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Qt.labs.platform

ApplicationWindow {
    width: 640
    height: 480
    visible: true
    title: qsTr("GuineaMPEG")
    Column {
        objectName: "col"
        anchors.centerIn: parent
        width: parent.width

        ScrollView {
            objectName: "sv"
            width: parent.width
            height : 400
            TextArea {
                text: "n/a"
                objectName: "textOutput"
                width: parent.width
            }
        }

        Text {
            color: "#ffffff"
            id: testLabel
            text: "Test 1"
        }

        Button {
            text: "Choose file"
            onClicked: function() {
                fileDialog.open()
            }
        }

        FileDialog {
            id: fileDialog
            folder: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]
            onAccepted: testLabel.text = file
        }
    }
}
