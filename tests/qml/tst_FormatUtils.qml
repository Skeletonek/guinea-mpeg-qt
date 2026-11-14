import "../../qml/Utils/FormatUtils.js" as FormatUtils
import QtQuick
import QtTest

TestCase {
    function test_streamText_video() {
        var stream = {
            "width": 1280,
            "height": 720,
            "codec": "h264",
            "fps": "30000/1001"
        };
        compare(FormatUtils.streamText(stream, 0, "video"), "1280x720 h264 30.0fps");
        stream.fps = "30/1";
        compare(FormatUtils.streamText(stream, 0, "video"), "1280x720 h264 30.0fps");
        stream.fps = "25";
        compare(FormatUtils.streamText(stream, 0, "video"), "1280x720 h264 25fps");
    }

    function test_streamText_audio() {
        var stream = {
            "codec": "aac",
            "title": "English"
        };
        compare(FormatUtils.streamText(stream, 0, "audio"), "English");
        stream.title = "";
        stream.language = "eng";
        compare(FormatUtils.streamText(stream, 0, "audio"), "eng");
        stream.language = "";
        compare(FormatUtils.streamText(stream, 1, "audio"), "Stream 2: aac");
    }

    function test_formatColor() {
        compare(FormatUtils.formatColor({"hdr": "HDR10", "color_primaries": "bt2020", "color_trc": "smpte2084"}), "HDR10 · BT.2020 · PQ");
        compare(FormatUtils.formatColor({"hdr": "HDR10+", "color_primaries": "bt2020", "color_trc": "smpte2084"}), "HDR10+ · BT.2020 · PQ");
        compare(FormatUtils.formatColor({"hdr": "HLG", "color_primaries": "bt2020", "color_trc": "arib-std-b67"}), "HLG · BT.2020");
        compare(FormatUtils.formatColor({"hdr": "Dolby Vision"}), "Dolby Vision");
        compare(FormatUtils.formatColor({"hdr": "SDR", "color_primaries": "bt709", "color_trc": "bt709"}), "BT.709");
        compare(FormatUtils.formatColor({"hdr": "SDR", "color_primaries": "unknown", "color_trc": "unknown"}), "SDR");
        compare(FormatUtils.formatColor({"hdr": "SDR"}), "SDR");
        compare(FormatUtils.formatColor({}), "N/A");
    }

    function test_getFilename() {
        compare(FormatUtils.getFilename("/a/b/c.mp4"), "c.mp4");
        compare(FormatUtils.getFilename("c.mp4"), "c.mp4");
        compare(FormatUtils.getFilename(""), "");
        compare(FormatUtils.getFilename("/"), "");
        compare(FormatUtils.getFilename("/a/b/"), "");
    }

    function test_getBaseFilename() {
        compare(FormatUtils.getBaseFilename("c.mp4"), "c");
        compare(FormatUtils.getBaseFilename("my.video.mp4"), "my.video");
        compare(FormatUtils.getBaseFilename("video"), "video");
    }

    function test_getDirectory() {
        compare(FormatUtils.getDirectory("/a/b/c.mp4"), "/a/b/");
        compare(FormatUtils.getDirectory("c.mp4"), "");
        compare(FormatUtils.getDirectory("/"), "/");
        compare(FormatUtils.getDirectory("/a/b/"), "/a/b/");
    }

    function test_fpsToDecimal() {
        verify(Math.abs(FormatUtils.fpsToDecimal("30000/1001") - 29.97) < 0.01);
        compare(FormatUtils.fpsToDecimal("30/1"), 30);
        compare(FormatUtils.fpsToDecimal("10/0"), null);
        compare(FormatUtils.fpsToDecimal("25"), null);
        compare(FormatUtils.fpsToDecimal(null), null);
    }

    function test_formatTimePrecise() {
        // Frame index when fps is known, padded to 2 digits
        compare(FormatUtils.formatTimePrecise(0, 30), "00:00.00");
        compare(FormatUtils.formatTimePrecise(1500, 30), "00:01.15");
        compare(FormatUtils.formatTimePrecise(59999, 30), "00:59.29");
        compare(FormatUtils.formatTimePrecise(61000, 25), "01:01.00");
        // Non-integer fps
        compare(FormatUtils.formatTimePrecise(1500, 23.976), "00:01.11");
        // Above 100 fps: 3-digit frame index so the counter width never changes
        compare(FormatUtils.formatTimePrecise(50, 120), "00:00.006");
        compare(FormatUtils.formatTimePrecise(995, 120), "00:00.119");
        // 100 fps stays at 2 digits (frames 0-99)
        compare(FormatUtils.formatTimePrecise(50, 100), "00:00.05");
        // Milliseconds when fps is unknown, padded to 3 digits
        compare(FormatUtils.formatTimePrecise(0), "00:00.000");
        compare(FormatUtils.formatTimePrecise(1500, 0), "00:01.500");
        compare(FormatUtils.formatTimePrecise(1500, null), "00:01.500");
        // Out-of-range input
        compare(FormatUtils.formatTimePrecise(-500, 30), "00:00.00");
        compare(FormatUtils.formatTimePrecise(3.6e+06, 30), "60:00.00");
    }

    function test_formatFps() {
        compare(FormatUtils.formatFps("30000/1001"), "29.97");
        compare(FormatUtils.formatFps(30), "30.00");
        compare(FormatUtils.formatFps(23.976), "23.98");
        compare(FormatUtils.formatFps(null), "?");
        compare(FormatUtils.formatFps("unknown"), "unknown");
    }

    name: "FormatUtils"
}
