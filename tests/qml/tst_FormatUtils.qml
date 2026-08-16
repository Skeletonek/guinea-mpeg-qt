import QtQuick
import QtTest
import "../../qml/Utils/FormatUtils.js" as FormatUtils

TestCase {
    name: "FormatUtils"

    function test_formatTime() {
        compare(FormatUtils.formatTime(0), "00:00")
        compare(FormatUtils.formatTime(999), "00:00")
        compare(FormatUtils.formatTime(1000), "00:01")
        compare(FormatUtils.formatTime(59000), "00:59")
        compare(FormatUtils.formatTime(60000), "01:00")
        compare(FormatUtils.formatTime(119000), "01:59")
        compare(FormatUtils.formatTime(3600000), "60:00")
        compare(FormatUtils.formatTime(3660000), "61:00")
    }

    function test_streamText_video() {
        var stream = { width: 1280, height: 720, codec: "h264", fps: "30000/1001" }
        compare(FormatUtils.streamText(stream, 0, "video"), "1280x720 h264 30.0fps")
        stream.fps = "30/1"
        compare(FormatUtils.streamText(stream, 0, "video"), "1280x720 h264 30.0fps")
        stream.fps = "25"
        compare(FormatUtils.streamText(stream, 0, "video"), "1280x720 h264 25fps")
    }

    function test_streamText_audio() {
        var stream = { codec: "aac", title: "English" }
        compare(FormatUtils.streamText(stream, 0, "audio"), "English")
        stream.title = ""
        stream.language = "eng"
        compare(FormatUtils.streamText(stream, 0, "audio"), "eng")
        stream.language = ""
        compare(FormatUtils.streamText(stream, 1, "audio"), "Stream 2: aac")
    }

    function test_getFilename() {
        compare(FormatUtils.getFilename("/a/b/c.mp4"), "c.mp4")
        compare(FormatUtils.getFilename("c.mp4"), "c.mp4")
        compare(FormatUtils.getFilename(""), "")
    }

    function test_getFilename_edgeCases() {
        compare(FormatUtils.getFilename("/"), "")
        compare(FormatUtils.getFilename("/a/b/"), "")
        compare(FormatUtils.getFilename("file with spaces.mp4"), "file with spaces.mp4")
        compare(FormatUtils.getFilename("/x/café_☃.mp4"), "café_☃.mp4")
        var longPath = "/" + new Array(101).join("dir/") + "clip.mp4"
        compare(FormatUtils.getFilename(longPath), "clip.mp4")
    }

    function test_getBaseFilename() {
        compare(FormatUtils.getBaseFilename("c.mp4"), "c")
        compare(FormatUtils.getBaseFilename("my.video.mp4"), "my.video")
        compare(FormatUtils.getBaseFilename("video"), "video")
    }

    function test_getBaseFilename_edgeCases() {
        compare(FormatUtils.getBaseFilename(".gitignore"), "")
        compare(FormatUtils.getBaseFilename("file."), "file")
        compare(FormatUtils.getBaseFilename("/a/b/my.tar.gz"), "/a/b/my.tar")
    }

    function test_getDirectory() {
        compare(FormatUtils.getDirectory("/a/b/c.mp4"), "/a/b/")
        compare(FormatUtils.getDirectory("c.mp4"), "")
        compare(FormatUtils.getDirectory("/"), "/")
        compare(FormatUtils.getDirectory("/a/b/"), "/a/b/")
    }

    function test_safeJsonParse() {
        var obj = FormatUtils.safeJsonParse('{"a": 1}')
        compare(obj.a, 1)
        var fallback = FormatUtils.safeJsonParse("bad json", { x: 42 })
        compare(fallback.x, 42)
        var empty = FormatUtils.safeJsonParse("bad json")
        compare(Object.keys(empty).length, 0)
    }

    function test_safeJsonParse_edgeCases() {
        compare(FormatUtils.safeJsonParse(null), null)
        compare(FormatUtils.safeJsonParse("null"), null)
        compare(FormatUtils.safeJsonParse("42"), 42)
        compare(FormatUtils.safeJsonParse("[]").length, 0)
        compare(FormatUtils.safeJsonParse('{"a": 1}').a, 1)
    }

    function test_fpsToDecimal() {
        verify(Math.abs(FormatUtils.fpsToDecimal("30000/1001") - 29.97) < 0.01)
        compare(FormatUtils.fpsToDecimal("30/1"), 30)
        compare(FormatUtils.fpsToDecimal("10/0"), null)
        compare(FormatUtils.fpsToDecimal("25"), null)
        compare(FormatUtils.fpsToDecimal(null), null)
    }

    function test_fpsToDecimal_edgeCases() {
        compare(FormatUtils.fpsToDecimal("0/1001"), 0)
        verify(Math.abs(FormatUtils.fpsToDecimal("29.97/1.001") - 29.94) < 0.01)
        compare(FormatUtils.fpsToDecimal("  30/1  "), 30)
        verify(isNaN(FormatUtils.fpsToDecimal("abc/def")))
    }

    function test_formatFps() {
        compare(FormatUtils.formatFps("30000/1001"), "29.97")
        compare(FormatUtils.formatFps(30), "30.00")
        compare(FormatUtils.formatFps(23.976), "23.98")
        compare(FormatUtils.formatFps(null), "?")
        compare(FormatUtils.formatFps("unknown"), "unknown")
    }

    function test_formatFps_edgeCases() {
        compare(FormatUtils.formatFps("0/1"), "0.00")
        compare(FormatUtils.formatFps("30/1"), "30.00")
        compare(FormatUtils.formatFps(0), "?")
    }
}