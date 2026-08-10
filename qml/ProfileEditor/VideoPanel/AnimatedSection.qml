import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../Utils/Constants.js" as Constants
import "../../Components"

Column {
    id: root
    width: parent.width
    visible: codecKey === "gif" || codecKey === "webp"
    spacing: 6

    property string codecKey: ""
    property bool loading: false

    signal changed

    SectionHeader {
        text: qsTr("Animated")
    }

    LabeledTextField {
        id: qualityField
        label: qsTr("Quality")
        placeholderText: "75"
        validator: IntValidator { bottom: 0; top: 100 }
        onTextChanged: if (!root.loading) root.changed()
    }

    LabeledRow {
        label: qsTr("Loop")
        Switch {
            id: loopSwitch
            checked: true
            onCheckedChanged: if (!root.loading) root.changed()
        }
    }

    function getAnimatedData() {
        return {
            quality: qualityField.text ? parseInt(qualityField.text) : null,
            loop_enabled: loopSwitch.checked ? true : false
        }
    }

    function setAnimatedData(d) {
        qualityField.text = d.quality != null ? String(d.quality) : "75"
        loopSwitch.checked = d.loop_enabled !== false
    }
}
