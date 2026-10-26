import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    property var _availableEncoders: ({})
    property var _codecAvailable: []
    readonly property var codec: Constants.codecKeys[codecCombo.currentIndex]
    readonly property var codecLabels: Constants.codecLabels

    signal encoderSelectionChanged(string encName)

    function rebuildCodecItems() {
        var avail = [];
        for (var i = 0; i < Constants.codecKeys.length; i++) {
            var key = Constants.codecKeys[i];
            if (key === "copy" || key === "gif" || key === "webp")
                avail.push(true);
            else
                avail.push(root._encodersForKey(key).length > 0);
        }
        root._codecAvailable = avail;
    }

    function _encodersForKey(key) {
        return root._availableEncoders[key] || [];
    }

    function _currentEncoderText() {
        var idx = encoderCombo.currentIndex;
        if (idx >= 0 && typeof encoderCombo.textAt === "function") {
            var text = encoderCombo.textAt(idx);
            if (text)
                return text;
        }
        return encoderCombo.currentText || "";
    }

    function rebuildEncoderModel(forceDefault) {
        var codec = Constants.codecKeys[codecCombo.currentIndex];
        if (codec === "copy") {
            encoderCombo.model = [];
            encoderCombo.currentIndex = -1;
            encoderCombo.editText = "";
            return;
        }
        var encs = root._encodersForKey(codec);
        var prev = root._currentEncoderText();
        encoderCombo.model = encs;
        if (encs.length === 0) {
            encoderCombo.currentIndex = -1;
            return;
        }
        if (!forceDefault && prev && encs.indexOf(prev) >= 0) {
            encoderCombo.currentIndex = encs.indexOf(prev);
            return;
        }
        var defEnc = Constants.defaultEncoders[codec] || Constants.defaultEncoders["h264"];
        var ei = encs.indexOf(defEnc);
        encoderCombo.currentIndex = ei >= 0 ? ei : 0;
    }

    function getCodecData() {
        var key = Constants.codecKeys[codecCombo.currentIndex];
        if (key === "copy")
            return {
                "codec": "copy",
                "encoder": null
            };
        return {
            "codec": key,
            "encoder": root._currentEncoderText() || null
        };
    }

    function getCurrentEncoder() {
        var key = Constants.codecKeys[codecCombo.currentIndex];
        if (key === "copy")
            return "copy";
        var text = root._currentEncoderText();
        return text || null;
    }

    function getCurrentCodecKey() {
        return Constants.codecKeys[codecCombo.currentIndex];
    }

    function setCodecData(d) {
        DataUtils.setIndex(Constants.codecKeys, codecCombo, d.codec);
        root.rebuildEncoderModel(true);
        if (d.codec === "copy")
            return;
        if (d.encoder) {
            var encs = root._encodersForKey(d.codec);
            var ei = encs.indexOf(d.encoder);
            if (ei >= 0)
                encoderCombo.currentIndex = ei;
            else
                encoderCombo.editText = d.encoder;
        }
    }

    LabeledRow {
        label: qsTr("Codec")

        ComboBox {
            id: codecCombo
            objectName: "codecCombo"

            model: root.codecLabels
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            onCurrentIndexChanged: {
                if (!root._codecAvailable[currentIndex]) {
                    root.encoderSelectionChanged("");
                    return;
                }
                var key = Constants.codecKeys[currentIndex];
                rebuildEncoderModel();
                if (key === "copy")
                    root.encoderSelectionChanged("copy");
                else
                    root.encoderSelectionChanged(root._currentEncoderText());
            }

            delegate: ItemDelegate {
                text: modelData + (root._codecAvailable[index] ? "" : " " + qsTr("(unavailable)"))
                enabled: root._codecAvailable[index]
                opacity: root._codecAvailable[index] ? 1 : 0.4
                palette.text: enabled ? theme.text : theme.textDim
            }
        }
    }

    LabeledRow {
        label: qsTr("Encoder")
        enabled: Constants.codecKeys[codecCombo.currentIndex] !== "copy"
        opacity: enabled ? 1.0 : 0.4

        ComboBox {
            id: encoderCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            enabled: Constants.codecKeys[codecCombo.currentIndex] !== "copy"
            onCurrentIndexChanged: root.encoderSelectionChanged(root._currentEncoderText());
            onEditTextChanged: root.emitChanged();
            onAccepted: root.encoderSelectionChanged(root._currentEncoderText());
        }
    }
}
