#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>
#include <clocale>

#include "guinea_mpeg_core.h"

static const char kDefaultProfilesToml[] = R"(
[[profiles]]
name = "H.264 High"
codec = "h264"
encoder = "libx264"
crf = 18
)";

static const char kGroupedProfilesToml[] = R"(
[[profiles]]
name = "H.264 High"
codec = "h264"
crf = 18

[[profiles]]
name = "H.264 Compatible"
codec = "h264"
crf = 23
category = "Compatibility"
)";

static QString takeRust(const char* s) {
    if (!s)
        return {};
    QString result = QString::fromUtf8(s);
    guinea_mpeg_free_string(s);
    return result;
}

static int indexOfArg(const QJsonArray& args, const QString& value) {
    for (int i = 0; i < args.size(); ++i) {
        if (args.at(i).toString() == value)
            return i;
    }
    return -1;
}

class TestBackendFfi : public QObject {
    Q_OBJECT

  private slots:
    void initTestCase();
    void encoderCapabilities();
    void encoderCapabilitiesEdgeCases();
    void buildFfmpegCommand();
    void buildFfmpegCommandRejectsInvalid();
    void buildFfmpegCommandWithCustomCommand();
    void previewCommandRejectsInvalid();
    void previewCustomCommand();
    void profileRoundtrip();
    void availableProfilesGrouped();
    void availableEncoders();
};

void TestBackendFfi::initTestCase() {
    setlocale(LC_NUMERIC, "C");
}

void TestBackendFfi::encoderCapabilities() {
    // JSON keys are the QML contract; the caps values are pinned via the args builder tests.
    const QString caps = takeRust(guinea_mpeg_encoder_capabilities("h264_nvenc"));
    const QJsonObject obj = QJsonDocument::fromJson(caps.toUtf8()).object();
    QVERIFY(obj.contains(QStringLiteral("crf_flag")));
    QVERIFY(obj.contains(QStringLiteral("rc_flag")));
    QVERIFY(obj.contains(QStringLiteral("uses_preset")));
    QVERIFY(obj.contains(QStringLiteral("uses_tune")));
    QVERIFY(obj.contains(QStringLiteral("uses_compression_level")));
    QVERIFY(obj.value(QStringLiteral("presets")).isArray());
    QVERIFY(obj.value(QStringLiteral("tunes")).isArray());
    QVERIFY(obj.value(QStringLiteral("pix_fmts")).isArray());
}

void TestBackendFfi::encoderCapabilitiesEdgeCases() {
    // Empty/unknown encoder names produce "null" (software caps are None);
    // null pointers must not crash.
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities("")), QStringLiteral("null"));
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities(nullptr)), QStringLiteral("null"));
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities("not_an_encoder")), QStringLiteral("null"));
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities("libx264")), QStringLiteral("null"));
}

void TestBackendFfi::buildFfmpegCommand() {
    const char* json =
        guinea_mpeg_build_ffmpeg_command("input.mp4", "output.mp4", 0.0, 0.0, R"({"codec":"h264","crf":18})");
    QVERIFY(json);
    const QJsonArray args = QJsonDocument::fromJson(QByteArray(json)).array();
    guinea_mpeg_free_string(json);
    QVERIFY(!args.isEmpty());
    QCOMPARE(args.first().toString(), QStringLiteral("-i"));
    QVERIFY(args.contains(QStringLiteral("-c:v")));
    QCOMPARE(args.at(indexOfArg(args, QStringLiteral("-c:v")) + 1).toString(), QStringLiteral("libx264"));
    QVERIFY(args.contains(QStringLiteral("-crf")));
    QCOMPARE(args.at(indexOfArg(args, QStringLiteral("-crf")) + 1).toString(), QStringLiteral("18"));
}

void TestBackendFfi::buildFfmpegCommandRejectsInvalid() {
    // Empty arguments or invalid profile JSON return NULL instead of a JSON array.
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("", "out.mp4", 0.0, 0.0, R"({"codec":"h264"})"));
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("in.mp4", "", 0.0, 0.0, R"({"codec":"h264"})"));
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("in.mp4", "out.mp4", 0.0, 0.0, ""));
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("in.mp4", "out.mp4", 0.0, 0.0, "not json"));
    // Null pointers must not crash.
    QVERIFY(!guinea_mpeg_build_ffmpeg_command(nullptr, nullptr, 0.0, 0.0, nullptr));
}

void TestBackendFfi::buildFfmpegCommandWithCustomCommand() {
    const char* json = guinea_mpeg_build_ffmpeg_command(
        "in.mp4", "out.mkv", 0.0, 0.0,
        R"({"codec":"h264","custom_command":"-c:v libx264 -crf 23 -preset fast -y {output}"})");
    QVERIFY(json);
    const QJsonArray args = QJsonDocument::fromJson(QByteArray(json)).array();
    guinea_mpeg_free_string(json);
    QCOMPARE(args.at(indexOfArg(args, QStringLiteral("-c:v")) + 1).toString(), QStringLiteral("libx264"));
    QCOMPARE(args.at(indexOfArg(args, QStringLiteral("-crf")) + 1).toString(), QStringLiteral("23"));
    QCOMPARE(args.last().toString(), QStringLiteral("out.mkv"));
    QVERIFY(!args.contains(QStringLiteral("-i")));
}

void TestBackendFfi::previewCommandRejectsInvalid() {
    QVERIFY(!guinea_mpeg_preview_command(""));
    QVERIFY(!guinea_mpeg_preview_command("not json"));
    QVERIFY(!guinea_mpeg_preview_command(nullptr));
}

void TestBackendFfi::previewCustomCommand() {
    const char* json =
        guinea_mpeg_preview_command(R"({"codec":"h264","custom_command":"-i {input} -c:v libx264 -y {output}"})");
    QVERIFY(json);
    const QJsonArray args = QJsonDocument::fromJson(QByteArray(json)).array();
    guinea_mpeg_free_string(json);
    QVERIFY(args.contains(QStringLiteral("[input]")));
    QCOMPARE(args.last().toString(), QStringLiteral("[output]"));
    QCOMPARE(args.at(indexOfArg(args, QStringLiteral("-c:v")) + 1).toString(), QStringLiteral("libx264"));
}

void TestBackendFfi::profileRoundtrip() {
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(QDir().mkpath(dir.path() + QLatin1String("/guinea-mpeg")));
    QFile f(dir.path() + QLatin1String("/guinea-mpeg/default_profiles.toml"));
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(kDefaultProfilesToml);
    f.close();
    qputenv("GUINEA_MPEG_CONFIG_DIR", dir.path().toUtf8());

    const QString defaultNames = takeRust(guinea_mpeg_default_profile_names());
    QVERIFY(defaultNames.contains(QStringLiteral("H.264 High")));

    QVERIFY(guinea_mpeg_save_profile("My Profile", R"({"codec":"h264","crf":23,"preset":"fast"})"));
    const QJsonObject loaded =
        QJsonDocument::fromJson(takeRust(guinea_mpeg_load_profile("My Profile")).toUtf8()).object();
    QCOMPARE(loaded.value("codec").toString(), QStringLiteral("h264"));
    QCOMPARE(loaded.value("crf").toInt(), 23);

    QVERIFY(guinea_mpeg_set_option("language", "pl"));
    const QJsonObject opts = QJsonDocument::fromJson(takeRust(guinea_mpeg_get_options()).toUtf8()).object();
    QCOMPARE(opts.value("language").toString(), QStringLiteral("pl"));

    qunsetenv("GUINEA_MPEG_CONFIG_DIR");
}

void TestBackendFfi::availableProfilesGrouped() {
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(QDir().mkpath(dir.path() + QLatin1String("/guinea-mpeg")));
    QFile f(dir.path() + QLatin1String("/guinea-mpeg/default_profiles.toml"));
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(kGroupedProfilesToml);
    f.close();
    qputenv("GUINEA_MPEG_CONFIG_DIR", dir.path().toUtf8());

    // Saving refreshes the merged config cache for this directory
    QVERIFY(guinea_mpeg_save_profile("My Web", R"({"codec":"vp9","category":"Web & streaming"})"));

    const QJsonArray groups = QJsonDocument::fromJson(takeRust(guinea_mpeg_available_profiles()).toUtf8()).array();
    QCOMPARE(groups.size(), 3);
    QCOMPARE(groups.at(0).toObject().value("category").toString(), QStringLiteral("Compatibility"));
    QCOMPARE(groups.at(0).toObject().value("names").toArray().size(), 1);
    QCOMPARE(groups.at(1).toObject().value("category").toString(), QStringLiteral("Web & streaming"));
    QCOMPARE(groups.at(1).toObject().value("names").toArray().at(0).toString(), QStringLiteral("My Web"));
    QCOMPARE(groups.at(2).toObject().value("category").toString(), QStringLiteral("Custom"));
    QCOMPARE(groups.at(2).toObject().value("names").toArray().at(0).toString(), QStringLiteral("H.264 High"));

    qunsetenv("GUINEA_MPEG_CONFIG_DIR");
}

void TestBackendFfi::availableEncoders() {
    const QJsonObject encoders = QJsonDocument::fromJson(takeRust(guinea_mpeg_available_encoders()).toUtf8()).object();
    QVERIFY(!encoders.isEmpty());
    QVERIFY(encoders.contains(QStringLiteral("h264")) || encoders.contains(QStringLiteral("hevc")) ||
            encoders.contains(QStringLiteral("vp8")));
}

QTEST_GUILESS_MAIN(TestBackendFfi)
#include "tst_backend_ffi.moc"