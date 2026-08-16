#include <QtTest>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <clocale>

#include "guinea_mpeg_core.h"

static const char kDefaultProfilesToml[] = R"(
[[profiles]]
name = "H.264 High"
codec = "h264"
encoder = "libx264"
crf = 18
)";

static QString takeRust(const char* s)
{
    if (!s) return {};
    QString result = QString::fromUtf8(s);
    guinea_mpeg_free_string(s);
    return result;
}

static int indexOfArg(const QJsonArray& args, const QString& value)
{
    for (int i = 0; i < args.size(); ++i) {
        if (args.at(i).toString() == value)
            return i;
    }
    return -1;
}

class TestBackendFfi : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void encoderCapabilities();
    void encoderCapabilitiesEdgeCases();
    void softwareEncoderHasNoCapabilities();
    void buildFfmpegCommand();
    void buildFfmpegCommandRejectsInvalid();
    void previewCommandRejectsInvalid();
    void profileRoundtrip();
    void availableEncoders();
    void mpvAvailable();
};

void TestBackendFfi::initTestCase()
{
    setlocale(LC_NUMERIC, "C");
}

void TestBackendFfi::encoderCapabilities()
{
    const QString caps = takeRust(guinea_mpeg_encoder_capabilities("h264_nvenc"));
    const QJsonObject obj = QJsonDocument::fromJson(caps.toUtf8()).object();
    QVERIFY(!obj.isEmpty());
    QCOMPARE(obj.value("crf_flag").toString(), QStringLiteral("-cq"));
    QCOMPARE(obj.value("rc_flag").toString(), QStringLiteral("-rc"));
    QCOMPARE(obj.value("uses_preset").toBool(), true);
}

void TestBackendFfi::softwareEncoderHasNoCapabilities()
{
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities("libx264")), QStringLiteral("null"));
}

void TestBackendFfi::encoderCapabilitiesEdgeCases()
{
    // Empty/unknown encoder names produce "null"; null pointers must not crash.
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities("")), QStringLiteral("null"));
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities(nullptr)), QStringLiteral("null"));
    QCOMPARE(takeRust(guinea_mpeg_encoder_capabilities("not_an_encoder")), QStringLiteral("null"));
}

void TestBackendFfi::buildFfmpegCommand()
{
    const char* json = guinea_mpeg_build_ffmpeg_command(
        "input.mp4", "output.mp4", 0.0, 0.0,
        R"({"codec":"h264","crf":18})");
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

void TestBackendFfi::buildFfmpegCommandRejectsInvalid()
{
    // Empty arguments or invalid profile JSON return NULL instead of a JSON array.
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("", "out.mp4", 0.0, 0.0, R"({"codec":"h264"})"));
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("in.mp4", "", 0.0, 0.0, R"({"codec":"h264"})"));
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("in.mp4", "out.mp4", 0.0, 0.0, ""));
    QVERIFY(!guinea_mpeg_build_ffmpeg_command("in.mp4", "out.mp4", 0.0, 0.0, "not json"));
    // Null pointers must not crash.
    QVERIFY(!guinea_mpeg_build_ffmpeg_command(nullptr, nullptr, 0.0, 0.0, nullptr));
}

void TestBackendFfi::previewCommandRejectsInvalid()
{
    QVERIFY(!guinea_mpeg_preview_command(""));
    QVERIFY(!guinea_mpeg_preview_command("not json"));
    QVERIFY(!guinea_mpeg_preview_command(nullptr));
}

void TestBackendFfi::profileRoundtrip()
{    QTemporaryDir dir;
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
    const QJsonObject loaded = QJsonDocument::fromJson(
        takeRust(guinea_mpeg_load_profile("My Profile")).toUtf8()).object();
    QCOMPARE(loaded.value("codec").toString(), QStringLiteral("h264"));
    QCOMPARE(loaded.value("crf").toInt(), 23);

    QVERIFY(guinea_mpeg_set_option("language", "pl"));
    const QJsonObject opts = QJsonDocument::fromJson(
        takeRust(guinea_mpeg_get_options()).toUtf8()).object();
    QCOMPARE(opts.value("language").toString(), QStringLiteral("pl"));

    qunsetenv("GUINEA_MPEG_CONFIG_DIR");
}

void TestBackendFfi::availableEncoders()
{
    const QJsonObject encoders = QJsonDocument::fromJson(
        takeRust(guinea_mpeg_available_encoders()).toUtf8()).object();
    QVERIFY(!encoders.isEmpty());
    QVERIFY(encoders.contains(QStringLiteral("h264"))
            || encoders.contains(QStringLiteral("hevc"))
            || encoders.contains(QStringLiteral("vp8")));
}

void TestBackendFfi::mpvAvailable()
{
    QVERIFY(guinea_mpeg_mpv_available());
}

QTEST_GUILESS_MAIN(TestBackendFfi)
#include "tst_backend_ffi.moc"