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

    function getData() {
        var idx = audioCodecCombo.currentIndex;
        var audioCodec = (!videoEnabled && audioEnabledSwitch.checked && idx >= 0) ? audioCodecLabels[idx] : null;
        var data = {
            "audio_enabled": audioForbidden ? false : audioEnabledSwitch.checked,
            "audio_bitrate": audioCodec === "FLAC" ? "" : (audioBitrateField.text || "128k"),
            "audio_channels": audioChannelsField.text ? parseInt(audioChannelsField.text) : null,
            "audio_sample_rate": audioSrField.text ? parseInt(audioSrField.text) : null,
            "audio_codec": audioCodec
        };
        return data;
    }

    function setData(d) {
        audioEnabledSwitch.checked = audioForbidden ? false : (d.audio_enabled !== false);
        audioChannelsField.text = d.audio_channels != null ? String(d.audio_channels) : "";
        audioSrField.text = d.audio_sample_rate != null ? String(d.audio_sample_rate) : "";
        if (d.audio_codec) {
            var aci = audioCodecLabels.indexOf(d.audio_codec);
            audioCodecCombo.currentIndex = aci >= 0 ? aci : 0;
            audioBitrateField.text = d.audio_codec === "FLAC" ? "" : (d.audio_bitrate || "128k");
        } else {
            audioCodecCombo.currentIndex = 0;
            audioBitrateField.text = d.audio_bitrate || "128k";
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
    onContainerChanged: _updateAutoCodecLabel()
    onCurrentCodecKeyChanged: _updateAutoCodecLabel()
    Component.onCompleted: _updateAutoCodecLabel()

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

        LabeledRow {
            visible: videoEnabled
            labelWidth: parent.width
            label: qsTr("Codec: Auto (%1)").arg(root._autoCodecLabel)
        }

        SectionHeader {
            text: qsTr("Codec")
            visible: !videoEnabled
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

        Column {
            width: parent.width
            spacing: 8

            LabeledTextField {
                id: audioBitrateField

                label: qsTr("Bitrate")
                placeholderText: "128k"
                visible: videoEnabled || audioCodecLabels[audioCodecCombo.currentIndex] !== "FLAC"
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
