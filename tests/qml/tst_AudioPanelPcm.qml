import "../../qml/ProfileEditor"
import QtQuick
import QtTest

Item {
    id: root

    // Stand-in for the C++ context property the panel expects
    property var theme: ({
            "text": "#ffffff",
            "textSecondary": "#cccccc",
            "textMuted": "#aaaaaa",
            "textDim": "#888888",
            "widget": "#333333",
            "widgetBorder": "#555555"
        })

    width: 600
    height: 600

    AudioPanel {
        id: audioPanel

        width: 400
        videoEnabled: true
    }

    TestCase {
        name: "AudioPanelPcm"
        when: windowShown

        function test_pcm_variant_roundtrip() {
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "pcm_s24le"
            });
            compare(audioPanel.getData().audio_codec, "pcm_s24le");
        }

        function test_pcm_shorthand_expands_to_s16le() {
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "pcm"
            });
            compare(audioPanel.getData().audio_codec, "pcm_s16le");
        }

        function test_auto_label_mirrors_rust_defaults() {
            audioPanel.container = "wav";
            compare(audioPanel._autoCodecLabel, "PCM");
            audioPanel.container = "avi";
            compare(audioPanel._autoCodecLabel, "MP3");
            audioPanel.container = "ogv";
            compare(audioPanel._autoCodecLabel, "Vorbis");
            audioPanel.container = "";
            audioPanel.currentCodecKey = "ffv1";
            compare(audioPanel._autoCodecLabel, "FLAC");
            audioPanel.currentCodecKey = "theora";
            compare(audioPanel._autoCodecLabel, "Vorbis");
            audioPanel.currentCodecKey = "mpeg4";
            compare(audioPanel._autoCodecLabel, "MP3");
        }
    }
}
