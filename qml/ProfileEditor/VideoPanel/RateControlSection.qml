import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import "../../Components"

Column {
    id: root
    spacing: 8
    width: parent.width

    property bool loading: false
    property var rateValidator: null

    signal changed

    LabeledRow {
        label: qsTr("Rate control")
        Row {
            spacing: 8
            width: parent.width - parent.effectiveLabelWidth - parent.spacing

            ComboBox {
                id: rateControlCombo
                model: Constants.rateControlLabels
                width: 100
                onCurrentIndexChanged: {
                    root.rateValidator = Constants.rateControlKeys[currentIndex] === "crf" ? crfValidatorInst : null
                    if (!root.loading) root.changed()
                }
            }

            TextField {
                id: rateValueField
                width: parent.width - rateControlCombo.width - root.spacing
                placeholderText: Constants.rateControlKeys[rateControlCombo.currentIndex] === "crf"
                    ? qsTr("CRF value (e.g. 18)") : qsTr("Bitrate (e.g. 2M)")
                validator: root.rateValidator
                onTextChanged: if (!root.loading) root.changed()
                onEditingFinished: if (!root.loading) root.changed()
            }
        }
    }

    IntValidator {
        id: crfValidatorInst
        bottom: Constants.crfMin
        top: Constants.crfMax
    }

    function getRateControlData() {
        var rcKey = Constants.rateControlKeys[rateControlCombo.currentIndex]
        var data = {
            rate_control: rcKey
        }
        if (rcKey === "crf") {
            data.crf = rateValueField.text ? parseInt(rateValueField.text) : null
            data.bitrate = null
        } else {
            data.crf = null
            data.bitrate = rateValueField.text || null
        }
        return data
    }

    function setRateControlData(d) {
        DataUtils.setIndex(Constants.rateControlKeys, rateControlCombo, d.rate_control)
        root.rateValidator = Constants.rateControlKeys[rateControlCombo.currentIndex] === "crf" ? crfValidatorInst : null

        if (Constants.rateControlKeys[rateControlCombo.currentIndex] === "crf") {
            rateValueField.text = d.crf != null ? String(d.crf) : ""
        } else {
            rateValueField.text = d.bitrate || ""
        }
    }
}
