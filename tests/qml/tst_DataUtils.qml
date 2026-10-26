import "../../qml/Utils/DataUtils.js" as DataUtils
import QtQuick
import QtTest

TestCase {
    function test_toLocalPath() {
        compare(DataUtils.toLocalPath("file:///home/user/video.mp4"), "/home/user/video.mp4");
        compare(DataUtils.toLocalPath("file:///home/user/my%20video.mp4"), "/home/user/my video.mp4");
        compare(DataUtils.toLocalPath("file:///home/user/caf%C3%A9.mp4"), "/home/user/café.mp4");
        compare(DataUtils.toLocalPath("/plain/path.mp4"), "/plain/path.mp4");
    }

    function test_toFileUrl() {
        compare(DataUtils.toFileUrl("/home/user/video.mp4"), "file:///home/user/video.mp4");
        compare(DataUtils.toFileUrl("/home/user/my video.mp4"), "file:///home/user/my%20video.mp4");
        // file:///C:/... required — "file://C:/..." parses the drive letter as a hostname
        compare(DataUtils.toFileUrl("C:/Users/user/video.mp4"), "file:///C:/Users/user/video.mp4");
        compare(DataUtils.toFileUrl("file:///already/a/url.mp4"), "file:///already/a/url.mp4");
    }

    function test_toggleSelection() {
        var sel = DataUtils.toggleSelection(2, true, [0, 1]);
        compare(sel.length, 3);
        compare(sel[2], 2);
        sel = DataUtils.toggleSelection(0, true, [0, 1]);
        compare(sel.length, 2);
        sel = DataUtils.toggleSelection(1, false, [0, 1]);
        compare(sel.length, 1);
        compare(sel[0], 0);
        sel = DataUtils.toggleSelection(5, false, [0, 1]);
        compare(sel.length, 2);
    }

    function test_buildProfileData() {
        var data = DataUtils.buildProfileData({
            "a": 1,
            "b": 2
        }, {
            "b": 3,
            "c": 4
        });
        compare(data.a, 1);
        compare(data.b, 3);
        compare(data.c, 4);
        compare(DataUtils.buildProfileData().hasOwnProperty("a"), false);
    }

    function test_profileRows() {
        var rows = DataUtils.profileRows([{
            "category": "General purpose",
            "names": ["B", "A"]
        }, {
            "category": "Animation",
            "names": []
        }]);
        compare(rows.length, 4);
        compare(rows[0].name, "General purpose");
        compare(rows[0].isHeader, true);
        compare(rows[1].name, "B");
        compare(rows[1].isHeader, false);
        compare(rows[2].name, "A");
        compare(rows[2].isHeader, false);
        compare(rows[3].name, "Animation");
        compare(rows[3].isHeader, true);
    }

    function test_profileRows_invalidJson() {
        compare(DataUtils.parseProfileRows("not json").length, 0);
        compare(DataUtils.parseProfileRows("[]").length, 0);
    }

    function test_comboText() {
        compare(DataUtils.comboText({
            "currentText": "value"
        }, "default"), "value");
        compare(DataUtils.comboText({
            "currentText": "default"
        }, "default"), null);
        compare(DataUtils.comboText({
            "currentText": ""
        }, "default"), null);
        compare(DataUtils.comboText({
            "currentText": null
        }, "default"), null);
    }

    function test_comboValue() {
        compare(DataUtils.comboValue({
            "currentText": "a"
        }), "a");
        // editable combo: a differing editText wins (typed value / stale-index fallback)
        compare(DataUtils.comboValue({
            "editable": true,
            "currentText": "fast",
            "editText": "slow"
        }), "slow");
        compare(DataUtils.comboValue({
            "editable": true,
            "currentText": "fast",
            "editText": "6"
        }), "6");
        // empty or identical editText falls through to currentText
        compare(DataUtils.comboValue({
            "editable": true,
            "currentText": "fast",
            "editText": ""
        }), "fast");
        compare(DataUtils.comboValue({
            "editable": true,
            "currentText": "fast",
            "editText": "fast"
        }), "fast");
    }

    function test_comboText_editable() {
        // regression: editable combo with a stale currentIndex reports editText
        compare(DataUtils.comboText({
            "editable": true,
            "currentText": "fast",
            "editText": "6"
        }, "default"), "6");
        compare(DataUtils.comboText({
            "editable": true,
            "currentText": "6",
            "editText": "6"
        }, "default"), "6");
        compare(DataUtils.comboText({
            "editable": true,
            "currentText": "default",
            "editText": "default"
        }, "default"), null);
    }

    function test_setComboText() {
        var items = ["a", "b", "c"];
        var combo = {
            "count": items.length,
            "textAt": function (i) {
                return items[i];
            },
            "currentIndex": 0,
            "editText": ""
        };
        DataUtils.setComboText(combo, "b", "default");
        compare(combo.currentIndex, 1);
        DataUtils.setComboText(combo, "default", "default");
        compare(combo.currentIndex, 0);
        DataUtils.setComboText(combo, null, "default");
        compare(combo.currentIndex, 0);
        DataUtils.setComboText(combo, "missing", "default");
        compare(combo.editText, "missing");
    }

    function test_setIndex() {
        var keys = ["a", "b"];
        var combo = {
            "currentIndex": -1
        };
        DataUtils.setIndex(keys, combo, "b");
        compare(combo.currentIndex, 1);
        DataUtils.setIndex(keys, combo, "nope");
        compare(combo.currentIndex, 0);
        DataUtils.setIndex([], combo, "x");
        compare(combo.currentIndex, 0);
        DataUtils.setIndex(keys, combo, undefined);
        compare(combo.currentIndex, 0);
    }

    function test_advancedTemplateFromArgs() {
        compare(DataUtils.advancedTemplateFromArgs(["-i", "[input]", "-c:v", "libx264", "-y", "[output]"]), "ffmpeg -i {input} -ss {start} -t {duration} -c:v libx264 -y {output}");
        compare(DataUtils.advancedTemplateFromArgs(["-c:v", "libx264"]), "ffmpeg -c:v libx264");
        compare(DataUtils.advancedTemplateFromArgs([]), "ffmpeg ");
        compare(DataUtils.advancedTemplateFromArgs(null), "");
        compare(DataUtils.advancedTemplateFromArgs(undefined), "");
    }

    function test_advancedTemplateFromArgs_quotingAndTrim() {
        // arg containing whitespace must be shell-quoted so it round-trips
        compare(DataUtils.advancedTemplateFromArgs(["-metadata", "title=Hello World", "-y", "[output]"]), "ffmpeg -metadata \"title=Hello World\" -y {output}");
        // no -i means no trim placeholders are injected
        compare(DataUtils.advancedTemplateFromArgs(["-i", "[input]", "-vf", "scale=-2:720"]), "ffmpeg -i {input} -ss {start} -t {duration} -vf scale=-2:720");
        // args already containing quotes get escaped
        compare(DataUtils.advancedTemplateFromArgs(["-vf", "eq=gamma=1.5,drawtext=text='hi'"]), "ffmpeg -vf eq=gamma=1.5,drawtext=text='hi'");
    }

    function test_uniquePath() {
        compare(DataUtils.uniquePath("/a/b_transcoded.webm", {}), "/a/b_transcoded.webm");
        compare(DataUtils.uniquePath("", {}), "");
        compare(DataUtils.uniquePath("/a/b.webm", null), "/a/b.webm");
    }

    function test_uniquePath_collisions() {
        var taken = {};
        var first = DataUtils.uniquePath("/a/b_transcoded.webm", taken);
        compare(first, "/a/b_transcoded.webm");
        taken[first] = true;
        var second = DataUtils.uniquePath("/a/b_transcoded.webm", taken);
        compare(second, "/a/b_transcoded_2.webm");
        taken[second] = true;
        compare(DataUtils.uniquePath("/a/b_transcoded.webm", taken), "/a/b_transcoded_3.webm");
    }

    function test_getExtensionForProfile_video() {
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": true,
            "codec": "h264"
        }, "/tmp/in.mkv"), "mp4");
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": true,
            "codec": "h264",
            "container": "mkv"
        }, "/tmp/in.mkv"), "mkv");
        // codec "copy" takes the input extension
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": true,
            "codec": "copy"
        }, "/tmp/in.mkv"), "mkv");
    }

    function test_getExtensionForProfile_audioOnly() {
        // labels are matched case-insensitively ("Opus" used to miss the map and fall back to ogg)
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": false,
            "audio_codec": "Opus"
        }, "/tmp/in.mkv"), "opus");
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": false,
            "audio_codec": "Vorbis"
        }, "/tmp/in.mkv"), "ogg");
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": false,
            "audio_codec": "FLAC"
        }, "/tmp/in.mkv"), "flac");
    }

    function test_getExtensionForProfile_missingAudioCodec() {
        // both streams disabled (legacy/imported profiles) must fall back, not throw
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": false,
            "audio_enabled": false,
            "audio_codec": null
        }, "/tmp/in.mkv"), "ogg");
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": false,
            "audio_codec": null,
            "container": "copy"
        }, "/tmp/in"), "mkv");
        compare(DataUtils.getExtensionForProfile({
            "video_enabled": false
        }, "/tmp/in.mkv"), "ogg");
    }

    name: "DataUtils"
}
