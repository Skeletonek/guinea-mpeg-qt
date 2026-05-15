import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "#1e1e1e"
    property string profileName: ""
    signal back

    Column {
        spacing: 10
        padding: 20
        width: parent.width

        Row {
            spacing: 10
            Button {
                text: "← Back"
                onClicked: back()
            }
            Label {
                text: "Edit Profile: " + profileName
                font.pixelSize: 18
                font.bold: true
                color: "white"
            }
            Button {
                text: "Save"
                onClicked: saveCurrent()
            }
        }

        Column {
            spacing: 10
            padding: 10
            width: parent.width

            Label { text: "Profile JSON:"; color: "white" }
            TextArea {
                id: profileJson
                width: parent.width
                height: 400
                color: "white"
                font.family: "monospace"
                wrapMode: TextArea.NoWrap
            }
        }
    }

    Component.onCompleted: {
        var config = backend.loadProfile(profileName)
        profileJson.text = JSON.stringify(JSON.parse(config), null, 2)
    }

    function saveCurrent() {
        backend.saveProfile(profileName, profileJson.text)
        back()
    }
}
