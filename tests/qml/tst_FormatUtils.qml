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
        compare(FormatUtils.formatTimePrecise(995, 120), "00:00.119");
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
