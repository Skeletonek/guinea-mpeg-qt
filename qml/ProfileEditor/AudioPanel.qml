import "../Components"
import "../Utils/Constants.js" as Constants
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
        var data = {
            "audio_enabled": audioForbidden ? false : audioEnabledSwitch.checked,
            "audio_bitrate": (isCopy || audioCodec === "FLAC") ? "" : (audioBitrateField.text || "128k"),
            "audio_channels": isCopy ? null : (audioChannelsField.text ? parseInt(audioChannelsField.text) : null),
            "audio_sample_rate": isCopy ? null : (audioSrField.text ? parseInt(audioSrField.text) : null),
            "audio_codec": audioCodec
        };
        return data;
    }

    function setData(d) {
        audioEnabledSwitch.checked = audioForbidden ? false : (d.audio_enabled !== false);
        audioChannelsField.text = d.audio_channels != null ? String(d.audio_channels) : "";
        audioSrField.text = d.audio_sample_rate != null ? String(d.audio_sample_rate) : "";
        var ac = d.audio_codec || null;
        // normalize copy case: backend uses "copy" lowercase, UI uses "Copy"
        var acLabel = ac ? (ac.toLowerCase() === "copy" ? "Copy" : ac) : null;
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
            audioChannelsField.text = "";
            audioSrField.text = "";
        }
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

            LabeledTextField {
                id: audioBitrateField

                label: qsTr("Bitrate")
                placeholderText: "128k"
                visible: !root._isAudioCopy && (videoEnabled || audioCodecLabels[audioCodecCombo.currentIndex] !== "FLAC")
                onTextChanged: {
                    if (!root.loading)
                        root.changed();
                }
            }

            LabeledTextField {
                id: audioChannelsField

                label: qsTr("Channels")
                placeholderText: "2"
                onTextChanged: {
                    if (!root.loading)
                        root.changed();
                }

                validator: IntValidator {
                    bottom: 0
                    top: 8
                }
            }

            LabeledTextField {
                id: audioSrField

                label: qsTr("Sample rate")
                placeholderText: "48000"
                onTextChanged: {
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
}
