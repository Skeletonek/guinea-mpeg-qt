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
        name: "AudioPanelRateControl"
        when: windowShown

        function test_modes_filtered_per_codec() {
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "mp3"
            });
            compare(audioPanel._rcKeys.join(","), "cbr,quality");
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "vorbis"
            });
            compare(audioPanel._rcKeys.join(","), "cbr,quality");
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "flac"
            });
            compare(audioPanel._rcKeys.join(","), "quality");
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "aac"
            });
            compare(audioPanel._rcKeys.join(","), "cbr");
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "opus"
            });
            compare(audioPanel._rcKeys.join(","), "cbr,vbr,quality");
        }

        function test_mp3_quality_roundtrip() {
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "mp3",
                "audio_filters": {
                    "rate_control": "quality",
                    "quality": "2"
                }
            });
            var d = audioPanel.getData();
            compare(d.audio_filters.rate_control, "quality");
            compare(d.audio_filters.quality, "2");
        }

        function test_legacy_vbr_maps_to_quality_for_lame() {
            audioPanel.setData({
                "audio_enabled": true,
                "audio_codec": "mp3",
                "audio_filters": {
                    "rate_control": "vbr",
                    "quality": "4"
                }
            });
            compare(audioPanel.getData().audio_filters.rate_control, "quality");
        }
    }
}
