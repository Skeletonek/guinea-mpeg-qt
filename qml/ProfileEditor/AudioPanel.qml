import "../Components"
import "../Utils/Constants.js" as Constants
import "../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    readonly property var audioCodecLabels: Constants.audioCodecLabels
    property bool videoEnabled: true
    property string currentCodecKey: "h264"
    property string container: ""
    property bool loading: false
    readonly property bool audioForbidden: currentCodecKey === "gif" || currentCodecKey === "webp"
    readonly property alias audioEnabled: audioEnabledSwitch.checked
    property string _autoCodecLabel: ""
    readonly property string _effectiveAudioCodecLabel: {
        if (!videoEnabled)
            return audioCodecLabels[audioCodecCombo.currentIndex] || "";
        var aIdx = audioAutoCombo.currentIndex;
        return aIdx > 0 ? audioCodecLabels[aIdx - 1] : _autoCodecLabel;
    }

    signal changed

    readonly property bool _isAudioCopy: {
        if (!audioEnabledSwitch.checked || audioForbidden)
            return false;
        if (!videoEnabled) {
            var idx = audioCodecCombo.currentIndex;
            return idx >= 0 && audioCodecLabels[idx] === "Copy";
        }
        var aIdx = audioAutoCombo.currentIndex;
        if (aIdx <= 0)
            return false;
        return audioCodecLabels[aIdx - 1] === "Copy";
    }

    function _rebuildAutoModel() {
        var model = ["Auto (" + root._autoCodecLabel + ")"];
        for (var i = 0; i < audioCodecLabels.length; i++)
            model.push(audioCodecLabels[i]);
        var prevIdx = audioAutoCombo.currentIndex;
        audioAutoCombo.model = model;
        if (prevIdx >= 0 && prevIdx < model.length) {
            audioAutoCombo.currentIndex = prevIdx;
        } else if (prevIdx >= model.length) {
            audioAutoCombo.currentIndex = 0;
        } else if (audioAutoCombo.currentIndex < 0) {
            audioAutoCombo.currentIndex = 0;
        }
    }

    function _comboInt(combo) {
        var text = DataUtils.comboValue(combo);
        var v = parseInt(text);
        return isNaN(v) || v <= 0 ? null : v;
    }

    function _showBitrate() {
        var rcKey = Constants.audioRateControlKeys[audioRateControlCombo.currentIndex];
        return rcKey === "cbr" || rcKey === "vbr";
    }

    function getData() {
        var audioCodec = null;
        if (audioEnabledSwitch.checked && !audioForbidden) {
            if (!videoEnabled) {
                var idx = audioCodecCombo.currentIndex;
                if (idx >= 0)
                    audioCodec = audioCodecLabels[idx];
                // map "Copy" sentinel to lowercase "copy" for backend
                if (audioCodec === "Copy")
                    audioCodec = "copy";
            } else {
                var aIdx = audioAutoCombo.currentIndex;
                if (aIdx > 0) {
                    audioCodec = audioCodecLabels[aIdx - 1];
                    if (audioCodec === "Copy")
                        audioCodec = "copy";
                } else {
                    audioCodec = null;
                }
            }
        }
        var isCopy = audioCodec && audioCodec.toLowerCase() === "copy";
        var showBitrate = !isCopy && audioCodec !== "FLAC" && _showBitrate();
        var data = {
            "audio_enabled": audioForbidden ? false : audioEnabledSwitch.checked,
            "audio_bitrate": showBitrate ? (audioBitrateField.text || "128k") : "",
            "audio_channels": isCopy ? null : _comboInt(channelsCombo),
            "audio_sample_rate": isCopy ? null : _comboInt(sampleRateCombo),
            "audio_codec": audioCodec
        };

        var af = {};
        var rcKey = Constants.audioRateControlKeys[audioRateControlCombo.currentIndex];
        if (rcKey !== "cbr")
            af.rate_control = rcKey;
        if (audioQualityField.text && audioQualityField.visible)
            af.quality = audioQualityField.text;
        var gain = parseFloat(audioGainField.text);
        if (!isNaN(gain))
            af.gain_db = gain;
        if (loudnormSwitch.checked) {
            af.loudnorm = true;
            af.loudnorm_i = parseFloat(loudnormIField.text);
            af.loudnorm_tp = parseFloat(loudnormTPField.text);
            af.loudnorm_lra = parseFloat(loudnormLRAField.text);
        }
        if (Object.keys(af).length > 0)
            data.audio_filters = af;

        return data;
    }

    function setData(d) {
        audioEnabledSwitch.checked = audioForbidden ? false : (d.audio_enabled !== false);
        var ac = d.audio_codec || null;
        // normalize copy case: backend uses "copy" lowercase, UI uses "Copy"
        var acLabel = ac ? (ac.toLowerCase() === "copy" ? "Copy" : ac) : null;
        if (acLabel) {
            // labels are title-cased ("AAC", "Opus", ...); normalize stored value
            for (var li = 0; li < audioCodecLabels.length; li++) {
                if (audioCodecLabels[li].toLowerCase() === acLabel.toLowerCase()) {
                    acLabel = audioCodecLabels[li];
                    break;
                }
            }
        }

        function _setComboValue(combo, value) {
            if (value == null || value === "") {
                combo.currentIndex = 0;
                return;
            }
            var s = String(value);
            for (var i = 0; i < combo.count; i++) {
                if (combo.textAt(i) === s) {
                    combo.currentIndex = i;
                    return;
                }
            }
            combo.editText = s;
        }

        if (!videoEnabled) {
            if (acLabel) {
                var aci = audioCodecLabels.indexOf(acLabel);
                audioCodecCombo.currentIndex = aci >= 0 ? aci : 0;
                audioBitrateField.text = acLabel === "FLAC" || acLabel === "Copy" ? "" : (d.audio_bitrate || "128k");
            } else {
                audioCodecCombo.currentIndex = 0;
                audioBitrateField.text = d.audio_bitrate || "128k";
            }
        } else {
            // videoEnabled: use auto combo. Rebuild model first to have labels.
            // defer index logic after model built
            var needsRebuild = audioAutoCombo.count === 0;
            if (needsRebuild)
                _rebuildAutoModel();
            if (acLabel) {
                var idx2 = audioCodecLabels.indexOf(acLabel);
                audioAutoCombo.currentIndex = idx2 >= 0 ? idx2 + 1 : 0;
                audioBitrateField.text = acLabel === "FLAC" || acLabel === "Copy" ? "" : (d.audio_bitrate || "128k");
            } else {
                audioAutoCombo.currentIndex = 0;
                audioBitrateField.text = d.audio_bitrate || "128k";
            }
        }
        if (acLabel === "Copy") {
            _setComboValue(channelsCombo, "");
            _setComboValue(sampleRateCombo, "");
        } else {
            _setComboValue(channelsCombo, d.audio_channels);
            _setComboValue(sampleRateCombo, d.audio_sample_rate);
        }

        var af = d.audio_filters || {};
        DataUtils.setIndex(Constants.audioRateControlKeys, audioRateControlCombo, af.rate_control || "cbr");
        audioQualityField.text = af.quality != null ? String(af.quality) : "";
        audioGainField.text = af.gain_db != null ? String(af.gain_db) : "";
        loudnormSwitch.checked = !!af.loudnorm;
        loudnormIField.text = String(af.loudnorm_i != null ? af.loudnorm_i : Constants.loudnormDefaultI);
        loudnormTPField.text = String(af.loudnorm_tp != null ? af.loudnorm_tp : Constants.loudnormDefaultTP);
        loudnormLRAField.text = String(af.loudnorm_lra != null ? af.loudnorm_lra : Constants.loudnormDefaultLRA);
    }

    function _updateAutoCodecLabel() {
        switch (root.container) {
        case "mp4":
        case "mov":
        case "m4a":
            root._autoCodecLabel = "AAC";
            return;
        case "webm":
        case "opus":
            root._autoCodecLabel = "Opus";
            return;
        case "ogg":
            root._autoCodecLabel = "Vorbis";
            return;
        case "mp3":
            root._autoCodecLabel = "MP3";
            return;
        case "flac":
            root._autoCodecLabel = "FLAC";
            return;
        }
        root._autoCodecLabel = (currentCodecKey === "h264" || currentCodecKey === "hevc") ? "AAC" : "Opus";
    }

    spacing: 8
    onContainerChanged: {
        _updateAutoCodecLabel();
        _rebuildAutoModel();
    }
    onCurrentCodecKeyChanged: {
        _updateAutoCodecLabel();
        _rebuildAutoModel();
    }
    Component.onCompleted: {
        _updateAutoCodecLabel();
        _rebuildAutoModel();
    }

    WidgetHeader {
        width: parent.width
        height: 28

        Row {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 8
            spacing: 8

            Label {
                text: qsTr("Audio")
                color: theme.text
                font.bold: true
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }

            Switch {
                id: audioEnabledSwitch

                checked: true
                enabled: !audioForbidden
                onCheckedChanged: {
                    if (!root.loading)
                        root.changed();
                }
            }
        }
    }

    Label {
        width: parent.width
        text: qsTr("Audio is not supported for GIF/WebP output.")
        color: theme.textSecondary
        wrapMode: Text.WordWrap
        visible: audioForbidden
    }

    Column {
        width: parent.width
        spacing: 8
        visible: audioEnabledSwitch.checked && !audioForbidden

        SectionHeader {
            text: qsTr("Codec")
        }

        ComboBox {
            id: audioAutoCombo

            visible: videoEnabled
            width: parent.width
            onCurrentIndexChanged: {
                if (!root.loading)
                    root.changed();
            }
        }

        ComboBox {
            id: audioCodecCombo

            visible: !videoEnabled
            model: audioCodecLabels
            width: parent.width
            onCurrentIndexChanged: {
                if (!root.loading)
                    root.changed();
            }
        }

        Label {
            width: parent.width
            visible: root._isAudioCopy
            text: qsTr("Audio will be copied without re-encoding (bitrate/channels/rate ignored).")
            color: theme.textSecondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Column {
            width: parent.width
            spacing: 8
            enabled: !root._isAudioCopy
            opacity: root._isAudioCopy ? 0.4 : 1.0

            LabeledRow {
                label: qsTr("Channels")

                ComboBox {
                    id: channelsCombo

                    width: parent.width - parent.effectiveLabelWidth - parent.spacing
                    editable: true
                    model: Constants.audioChannelOptions
                    currentIndex: 0
                    onCurrentIndexChanged: {
                        if (!root.loading)
                            root.changed();
                    }
                    onEditTextChanged: {
                        if (!root.loading)
                            root.changed();
                    }

                    validator: IntValidator {
                        bottom: 0
                        top: 8
                    }
                }
            }

            LabeledRow {
                label: qsTr("Sample rate")

                ComboBox {
                    id: sampleRateCombo

                    width: parent.width - parent.effectiveLabelWidth - parent.spacing
                    editable: true
                    model: Constants.audioSampleRateOptions
                    currentIndex: 0
                    onCurrentIndexChanged: {
                        if (!root.loading)
                            root.changed();
                    }
                    onEditTextChanged: {
                        if (!root.loading)
                            root.changed();
                    }

                    validator: IntValidator {
                        bottom: 0
                        top: 192000
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8
            enabled: !root._isAudioCopy
            opacity: root._isAudioCopy ? 0.4 : 1.0

            SectionHeader {
                text: qsTr("Processing")
            }

            LabeledRow {
                label: qsTr("Rate control")

                ComboBox {
                    id: audioRateControlCombo

                    width: parent.width - parent.effectiveLabelWidth - parent.spacing
                    model: Constants.audioRateControlLabels
                    currentIndex: 0
                    onCurrentIndexChanged: {
                        if (!root.loading)
                            root.changed();
                    }
                }
            }

            LabeledTextField {
                id: audioBitrateField

                label: qsTr("Bitrate")
                placeholderText: "128k"
                visible: !root._isAudioCopy && root._effectiveAudioCodecLabel !== "FLAC" && root._showBitrate()
                onTextChanged: {
                    if (!root.loading)
                        root.changed();
                }
            }

            LabeledTextField {
                id: audioQualityField

                label: qsTr("Quality")
                placeholderText: "4"
                visible: Constants.audioRateControlKeys[audioRateControlCombo.currentIndex] !== "cbr"
                onTextChanged: {
                    if (!root.loading)
                        root.changed();
                }
            }

            LabeledTextField {
                id: audioGainField

                label: qsTr("Gain (dB)")
                placeholderText: "0"
                onTextChanged: {
                    if (!root.loading)
                        root.changed();
                }

                validator: DoubleValidator {
                    bottom: -60
                    top: 60
                    decimals: 1
                }
            }

            LabeledRow {
                label: qsTr("Loudnorm")

                Switch {
                    id: loudnormSwitch

                    onCheckedChanged: {
                        if (!root.loading)
                            root.changed();
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: loudnormSwitch.checked

                LabeledTextField {
                    id: loudnormIField

                    label: qsTr("Target I (LUFS)")
                    placeholderText: String(Constants.loudnormDefaultI)
                    onTextChanged: {
                        if (!root.loading)
                            root.changed();
                    }

                    validator: DoubleValidator {
                        bottom: -70
                        top: -5
                        decimals: 1
                    }
                }

                LabeledTextField {
                    id: loudnormTPField

                    label: qsTr("True peak (dBTP)")
                    placeholderText: String(Constants.loudnormDefaultTP)
                    onTextChanged: {
                        if (!root.loading)
                            root.changed();
                    }

                    validator: DoubleValidator {
                        bottom: -20
                        top: 0
                        decimals: 1
                    }
                }

                LabeledTextField {
                    id: loudnormLRAField

                    label: qsTr("LRA")
                    placeholderText: String(Constants.loudnormDefaultLRA)
                    onTextChanged: {
                        if (!root.loading)
                            root.changed();
                    }

                    validator: DoubleValidator {
                        bottom: 1
                        top: 50
                        decimals: 1
                    }
                }
            }
        }
    }
}
