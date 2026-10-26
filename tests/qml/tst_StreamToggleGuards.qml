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
                return "{}";
            },
            "encoderCapabilities": function () {
                return "null";
            }
        })

    width: 600
    height: 400

    VideoPanel {
        id: videoPanel

        width: parent.width / 2
        audioEnabled: audioPanel.audioEnabled && !audioPanel.audioForbidden
    }

    AudioPanel {
        id: audioPanel

        width: parent.width / 2
        videoEnabled: videoPanel.videoEnabled
    }

    TestCase {
        name: "StreamToggleGuards"
        when: windowShown

        // Both streams may never end up disabled: the switch of the only
        // enabled stream is blocked until the other one comes back on.
        function test_one_stream_cannot_be_disabled() {
            var videoSwitch = findChild(videoPanel, "videoEnabledSwitch");
            var audioSwitch = findChild(audioPanel, "audioEnabledSwitch");

            videoSwitch.checked = true;
            audioSwitch.checked = true;
            compare(videoSwitch.enabled, true);
            compare(audioSwitch.enabled, true);

            audioSwitch.checked = false;
            compare(videoSwitch.enabled, false);
            compare(audioSwitch.enabled, true);

            audioSwitch.checked = true;
            videoSwitch.checked = false;
            compare(videoSwitch.enabled, true);
            compare(audioSwitch.enabled, false);
        }

        function test_both_off_state_is_escapable() {
            var videoSwitch = findChild(videoPanel, "videoEnabledSwitch");
            var audioSwitch = findChild(audioPanel, "audioEnabledSwitch");

            videoSwitch.checked = false;
            audioSwitch.checked = false;
            compare(videoSwitch.enabled, true);
            compare(audioSwitch.enabled, true);
        }

        function test_video_stays_on_when_codec_has_no_audio() {
            var videoSwitch = findChild(videoPanel, "videoEnabledSwitch");
            var audioSwitch = findChild(audioPanel, "audioEnabledSwitch");

            videoSwitch.checked = true;
            audioSwitch.checked = true;
            audioPanel.currentCodecKey = "gif";
            compare(audioSwitch.enabled, false);
            compare(videoSwitch.enabled, false);
            audioPanel.currentCodecKey = "h264";
        }
    }
}
