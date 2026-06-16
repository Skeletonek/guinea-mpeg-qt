import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import "../../Components"

Column {
    id: root
    spacing: 8
    width: parent.width

    property var _availableEncoders: ({})
    property var _codecAvailable: []
    property bool loading: false

    signal changed
    signal openEncoderCompatDialog
    signal encoderSelectionChanged(string encName)

    readonly property var codec: Constants.codecKeys[codecCombo.currentIndex]
    readonly property var codecLabels: Constants.codecLabels
    readonly property var codecKeys: Constants.codecKeys

    LabeledRow {
        label: "Codec"
        ComboBox {
            id: codecCombo
            model: root.codecLabels
            width: parent.width - root.spacing - 130
            delegate: ItemDelegate {
                text: modelData + (root._codecAvailable[index] ? "" : " (unavailable)")
                enabled: root._codecAvailable[index]
                opacity: root._codecAvailable[index] ? 1.0 : 0.4
                palette.text: enabled ? theme.text : theme.textDim
            }
            onCurrentIndexChanged: {
                if (!root._codecAvailable[currentIndex]) {
                    root.encoderSelectionChanged("")
                    return
                }
                rebuildEncoderModel()
                root.encoderSelectionChanged(root._currentEncoderText())
            }
        }
    }

    LabeledRow {
        label: "Encoder"
        Row {
            spacing: 8
            width: parent.width - 130 - root.spacing

            Button {
                id: compatInfoBtn
                width: 32
                height: 32
                text: "?"
                font.bold: true
                font.pixelSize: 15
                onClicked: root.openEncoderCompatDialog()
                ToolTip.visible: hovered
                ToolTip.text: "Show available encoders"
            }

            ComboBox {
                id: encoderCombo
                width: parent.width - compatInfoBtn.width - root.spacing
                editable: true
                onCurrentIndexChanged: {
                    root.encoderSelectionChanged(root._currentEncoderText())
                }
                onEditTextChanged: {
                    if (!root.loading) root.changed()
                }
                onAccepted: {
                    root.encoderSelectionChanged(root._currentEncoderText())
                }
            }
        }
    }

    function rebuildCodecItems() {
        var avail = []
        for (var i = 0; i < Constants.codecKeys.length; i++) {
            avail.push(root._encodersForKey(Constants.codecKeys[i]).length > 0)
        }
        root._codecAvailable = avail
    }

    function _encodersForKey(key) {
        return root._availableEncoders[key] || []
    }

    function _currentEncoderText() {
        var idx = encoderCombo.currentIndex
        if (idx >= 0 && typeof encoderCombo.textAt === "function") {
            var text = encoderCombo.textAt(idx)
            if (text) return text
        }
        return encoderCombo.currentText || ""
    }

    function rebuildEncoderModel(forceDefault) {
        var codec = Constants.codecKeys[codecCombo.currentIndex]
        var encs = root._encodersForKey(codec)
        var prev = root._currentEncoderText()
        encoderCombo.model = encs
        if (encs.length === 0) {
            encoderCombo.currentIndex = -1
            return
        }
        if (!forceDefault && prev && encs.indexOf(prev) >= 0) {
            encoderCombo.currentIndex = encs.indexOf(prev)
            return
        }
        var defEnc = Constants.defaultEncoders[codec] || Constants.defaultEncoders["h264"]
        var ei = encs.indexOf(defEnc)
        encoderCombo.currentIndex = ei >= 0 ? ei : 0
    }

    function getCodecData() {
        return {
            codec: Constants.codecKeys[codecCombo.currentIndex],
            encoder: root._currentEncoderText() || null
        }
    }

    function getCurrentEncoder() {
        var text = root._currentEncoderText()
        return text || null
    }

    function setCodecData(d) {
        DataUtils.setIndex(Constants.codecKeys, codecCombo, d.codec)

        root.rebuildEncoderModel(true)
        if (d.encoder) {
            var encs = root._encodersForKey(d.codec)
            var ei = encs.indexOf(d.encoder)
            if (ei >= 0)
                encoderCombo.currentIndex = ei
            else
                encoderCombo.editText = d.encoder
        }
    }
}
