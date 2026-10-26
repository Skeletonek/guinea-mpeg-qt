import "../../qml/ProfileEditor"
import QtQuick
import QtTest

Item {
    id: root

    // Stand-ins for the C++ context properties the panels expect
    property var theme: ({
            "text": "#ffffff",
            "textSecondary": "#cccccc",
            "textMuted": "#aaaaaa",
            "textDim": "#888888",
            "widget": "#333333",
            "widgetBorder": "#555555"
        })
    property var backend: ({
            "availableEncoders": function () {
                return "{\"h264\":[\"libx264\"],\"vp9\":[\"libvpx-vp9\"],\"av1\":[\"libsvtav1\"]}";
            },
            "encoderCapabilities": function () {
                return "null";
            }
        })

    width: 600
    height: 400

    VideoPanel {
        id: videoPanel

        width: parent.width
    }

    TestCase {
        name: "CodecPresetWiring"
        when: windowShown

        // Regression: switching the codec used to rebuild the preset model with
        // the previous codec's key — the rebuild runs inside the codec combo's
        // change chain, before the codec property propagates to the section.
        function test_preset_model_follows_interactive_codec_switch() {
            videoPanel.setData({
                "codec": "h264",
                "encoder": "libx264",
                "rate_control": "crf"
            });
            var codecCombo = findChild(videoPanel, "codecCombo");
            var presetCombo = findChild(videoPanel, "presetCombo");
            compare(JSON.stringify(presetCombo.model), JSON.stringify(["default", "ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"]));

            // codecKeys order: h264, hevc, vp8, vp9, av1, ...
            codecCombo.currentIndex = 3;
            compare(JSON.stringify(presetCombo.model), JSON.stringify(["default", "good", "best", "realtime"]));

            codecCombo.currentIndex = 4;
            compare(JSON.stringify(presetCombo.model), JSON.stringify(["default", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"]));
        }
    }
}
