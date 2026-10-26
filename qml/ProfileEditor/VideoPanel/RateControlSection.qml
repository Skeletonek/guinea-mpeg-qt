import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    property var rateValidator: null
    property var _capOverrides: ({})
    property bool isAnimated: false
    property bool isCopy: false
    readonly property bool _hasRateControl: _capOverrides.crf_flag !== ""
    readonly property bool _isQualityValue: !!_capOverrides.crf_flag && _capOverrides.crf_flag !== "-crf"
    readonly property bool _hasCustomRange: _capOverrides.crf_min != null
    readonly property int _crfBottom: _capOverrides.crf_min != null ? _capOverrides.crf_min : Constants.crfMin
    readonly property int _crfTop: _capOverrides.crf_max != null ? _capOverrides.crf_max : Constants.crfMax
    readonly property var _modeLabels: [_isQualityValue ? "Quality" : Constants.rateControlLabels[0], Constants.rateControlLabels[1], Constants.rateControlLabels[2]]

    visible: !isAnimated && !isCopy && _hasRateControl

    on_CapOverridesChanged: clampCrfValue()

    function _valuePlaceholder() {
        if (Constants.rateControlKeys[rateControlCombo.currentIndex] !== "crf")
            return qsTr("Bitrate (e.g. 2M)");
        if (root._hasCustomRange)
            return root._crfBottom + "-" + root._crfTop;
        return root._isQualityValue ? qsTr("Quality value (e.g. 18)") : qsTr("CRF value (e.g. 18)");
    }

    function clampCrfValue() {
        if (Constants.rateControlKeys[rateControlCombo.currentIndex] !== "crf")
            return;

        var v = parseInt(rateValueField.text);
        if (isNaN(v))
            return;

        var clamped = Math.max(root._crfBottom, Math.min(root._crfTop, v));
        if (clamped !== v)
            rateValueField.text = String(clamped);
    }

    function getRateControlData() {
        if (!root._hasRateControl)
            return {
                "rate_control": null,
                "crf": null,
                "bitrate": null
            };

        var rcKey = Constants.rateControlKeys[rateControlCombo.currentIndex];
        var data = {
            "rate_control": rcKey
        };
        if (rcKey === "crf") {
            data.crf = rateValueField.text ? parseInt(rateValueField.text) : null;
            data.bitrate = null;
        } else {
            data.crf = null;
            data.bitrate = rateValueField.text || null;
        }
        return data;
    }

    function setRateControlData(d) {
        DataUtils.setIndex(Constants.rateControlKeys, rateControlCombo, d.rate_control);
        root.rateValidator = Constants.rateControlKeys[rateControlCombo.currentIndex] === "crf" ? crfValidatorInst : null;
        if (Constants.rateControlKeys[rateControlCombo.currentIndex] === "crf")
            rateValueField.text = d.crf != null ? String(d.crf) : "";
        else
            rateValueField.text = d.bitrate || "";
    }

    LabeledRow {
        label: qsTr("Rate control")

        Row {
            spacing: 8
            width: parent.width - parent.effectiveLabelWidth - parent.spacing

            ComboBox {
                id: rateControlCombo

                model: root._modeLabels
                width: 100
                onCurrentIndexChanged: {
                    root.rateValidator = Constants.rateControlKeys[currentIndex] === "crf" ? crfValidatorInst : null;
                    root.emitChanged();
                }
            }

            TextField {
                id: rateValueField

                width: parent.width - rateControlCombo.width - root.spacing
                placeholderText: root._valuePlaceholder()
                validator: root.rateValidator
                onTextChanged: root.emitChanged();
            }
        }
    }

    IntValidator {
        id: crfValidatorInst

        bottom: root._crfBottom
        top: root._crfTop
    }
}
