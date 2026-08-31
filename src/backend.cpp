#include "backend.h"
#include "guinea_mpeg_core.h"
#include <QApplication>
#include <QClipboard>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#ifdef Q_OS_LINUX
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#endif
#ifdef Q_OS_WIN
#include <QIcon>
#endif

namespace {

QString takeRustString(const char* s, const QString& fallback = QString()) {
    if (!s)
        return fallback;
    QString result = QString::fromUtf8(s);
    guinea_mpeg_free_string(s);
    return result;
}

QStringList jsonArgsToStringList(const QByteArray& json) {
    QStringList args;
    QJsonDocument doc = QJsonDocument::fromJson(json);
    if (doc.isArray())
        for (const auto& arg : doc.array())
            args << arg.toString();
    return args;
}

double jsonDouble(const QJsonValue& v, double fallback = 0.0) {
    if (v.isDouble())
        return v.toDouble();
    if (v.isString())
        return v.toString().toDouble();
    return fallback;
}

qint64 jsonInt64(const QJsonValue& v) {
    if (v.isDouble())
        return static_cast<qint64>(v.toDouble());
    if (v.isString()) {
        bool ok = false;
        const qint64 r = v.toString().toLongLong(&ok);
        if (ok)
            return r;
    }
    return 0;
}

void killTranscodeProcess(std::unique_ptr<QProcess>& proc) {
    if (!proc)
        return;
    proc->disconnect();
    proc->kill();
    proc->waitForFinished(3000);
    proc.reset();
}

void releaseProcess(std::unique_ptr<QProcess>& slot, QProcess* proc) {
    proc->deleteLater();
    if (slot.get() == proc)
        slot.release(); // NOLINT: ownership moves to deleteLater
}

QVariantMap makeVideoStreamMap(int idx, const QJsonObject& stream) {
    QVariantMap m;
    m["index"] = idx;
    m["codec"] = stream["codec_name"].toString();
    m["width"] = stream["width"].toInt();
    m["height"] = stream["height"].toInt();
    m["fps"] = stream["r_frame_rate"].toString();
    return m;
}

QVariantMap makeAudioStreamMap(int idx, const QJsonObject& stream) {
    const QJsonObject tags = stream["tags"].toObject();
    QVariantMap m;
    m["index"] = idx;
    m["codec"] = stream["codec_name"].toString();
    m["channels"] = stream["channels"].toInt();
    m["sample_rate"] = stream["sample_rate"].toString();
    m["language"] = tags["language"].toString();
    m["title"] = tags["title"].toString();
    return m;
}

} // namespace

GuineaMpegBackendExt::GuineaMpegBackendExt(QObject* parent) : QObject(parent) {
#ifdef Q_OS_WIN
    m_trayIcon = new QSystemTrayIcon(this);
    m_trayIcon->setIcon(QIcon(QStringLiteral(":/media/logo/logo.png")));
    // showMessage() needs a visible tray icon to post native Win10/11 toasts.
    m_trayIcon->show();
#endif
}

GuineaMpegBackendExt::~GuineaMpegBackendExt() {
    killTranscodeProcess(m_currentTranscode);
    killTranscodeProcess(m_currentPreview);
}

void GuineaMpegBackendExt::setTranscodeOutput(const QString& v) {
    m_transcodeOutput = v;
    emit transcodeOutputUpdated();
}

void GuineaMpegBackendExt::setTranscoding(bool v) {
    m_transcoding = v;
    emit transcodingChanged();
}

void GuineaMpegBackendExt::setPreviewGenerating(bool v) {
    m_previewGenerating = v;
    emit previewGeneratingChanged();
}

void GuineaMpegBackendExt::resetPreview() {
    if (m_lastPreviewPath.isEmpty() && m_lastPreviewSize == 0)
        return;
    m_lastPreviewPath.clear();
    m_lastPreviewSize = 0;
    emit lastPreviewPathChanged();
    emit lastPreviewSizeChanged();
}

QString GuineaMpegBackendExt::defaultProfileNames() {
    return takeRustString(guinea_mpeg_default_profile_names());
}

QString GuineaMpegBackendExt::availableProfiles() {
    return takeRustString(guinea_mpeg_available_profiles());
}

QString GuineaMpegBackendExt::userProfileNames() {
    return takeRustString(guinea_mpeg_user_profile_names());
}

QString GuineaMpegBackendExt::loadProfile(const QString& name) {
    return takeRustString(guinea_mpeg_load_profile(name.toUtf8().constData()));
}

bool GuineaMpegBackendExt::saveProfile(const QString& name, const QString& json) {
    return guinea_mpeg_save_profile(name.toUtf8().constData(), json.toUtf8().constData());
}

QString GuineaMpegBackendExt::availableEncoders() {
    return takeRustString(guinea_mpeg_available_encoders(), QStringLiteral("null"));
}

QString GuineaMpegBackendExt::encoderCapabilities(const QString& encoderName) {
    return takeRustString(guinea_mpeg_encoder_capabilities(encoderName.toUtf8().constData()), QStringLiteral("null"));
}

void GuineaMpegBackendExt::copyToClipboard(const QString& text) {
    if (auto* cb = QGuiApplication::clipboard())
        cb->setText(text);
}

QString GuineaMpegBackendExt::generateCommandPreview(const QString& json) {
    return takeRustString(guinea_mpeg_preview_command(json.toUtf8().constData()));
}

bool GuineaMpegBackendExt::deleteProfile(const QString& name) {
    return guinea_mpeg_delete_profile(name.toUtf8().constData());
}

bool GuineaMpegBackendExt::restoreDefaultProfiles() {
    return guinea_mpeg_restore_defaults();
}

bool GuineaMpegBackendExt::exportProfiles(const QString& path, const QString& namesJson) {
    return guinea_mpeg_export_profiles(path.toUtf8().constData(), namesJson.toUtf8().constData());
}

QString GuineaMpegBackendExt::importProfilesPreview(const QString& path) {
    return takeRustString(guinea_mpeg_import_profiles_preview(path.toUtf8().constData()), QStringLiteral("{}"));
}

QString GuineaMpegBackendExt::importProfiles(const QString& path, bool overwrite) {
    return takeRustString(guinea_mpeg_import_profiles(path.toUtf8().constData(), overwrite), QStringLiteral("{}"));
}

QString GuineaMpegBackendExt::getOptions() {
    return takeRustString(guinea_mpeg_get_options(), QStringLiteral("{}"));
}

bool GuineaMpegBackendExt::setOption(const QString& key, const QString& value) {
    return guinea_mpeg_set_option(key.toUtf8().constData(), value.toUtf8().constData());
}

bool GuineaMpegBackendExt::fileExists(const QString& rawPath) {
    return QFileInfo(QDir::cleanPath(rawPath)).exists();
}

void GuineaMpegBackendExt::systemBeep() {
    QApplication::beep();
}

QVariantMap GuineaMpegBackendExt::getVideoInfo(const QString& rawPath) {
    const char* json = guinea_mpeg_video_info(rawPath.toUtf8().constData());
    QVariantMap info;
    if (!json) {
        info["duration"] = 0.0;
        return info;
    }

    const QJsonObject root = QJsonDocument::fromJson(QByteArray(json)).object();
    guinea_mpeg_free_string(json);

    info["duration"] = jsonDouble(root["format"].toObject()["duration"]);

    QVariantList videoStreams;
    QVariantList audioStreams;
    int videoTypeIdx = 0;
    int audioTypeIdx = 0;

    const QJsonArray streams = root["streams"].toArray();
    for (const auto& s : streams) {
        const QJsonObject stream = s.toObject();
        const QString type = stream["codec_type"].toString();
        if (type == "video") {
            if (!info.contains("codec")) {
                info["width"] = stream["width"].toInt();
                info["height"] = stream["height"].toInt();
                info["codec"] = stream["codec_name"].toString();
                info["fps"] = stream["r_frame_rate"].toString();
                info["bitrate"] = jsonInt64(stream["bit_rate"]);
            }
            videoStreams.append(makeVideoStreamMap(videoTypeIdx++, stream));
        } else if (type == "audio") {
            if (!info.contains("audio_codec"))
                info["audio_codec"] = stream["codec_name"].toString();
            audioStreams.append(makeAudioStreamMap(audioTypeIdx++, stream));
        }
    }
    info["video_streams"] = videoStreams;
    info["audio_streams"] = audioStreams;
    return info;
}

bool GuineaMpegBackendExt::ffmpegAvailable() {
    return guinea_mpeg_ffmpeg_available();
}

QString GuineaMpegBackendExt::getFfmpegVersion() {
    return takeRustString(guinea_mpeg_ffmpeg_version());
}

QString GuineaMpegBackendExt::getMpvVersion() {
    return takeRustString(guinea_mpeg_mpv_version());
}

QString GuineaMpegBackendExt::generatePreview(const QString& rawPath, qint64 timeMs) {
    return takeRustString(guinea_mpeg_generate_preview(rawPath.toUtf8().constData(), (long long)timeMs));
}

static QStringList buildArgsFromProfile(const QString& input, const QString& output, double startTime, double endTime,
                                        const QString& profileJson) {
    const char* jsonArgs = guinea_mpeg_build_ffmpeg_command(input.toUtf8().constData(), output.toUtf8().constData(),
                                                            startTime, endTime, profileJson.toUtf8().constData());
    if (!jsonArgs)
        return {};
    QStringList args = jsonArgsToStringList(QByteArray(jsonArgs));
    guinea_mpeg_free_string(jsonArgs);
    return args;
}

QString GuineaMpegBackendExt::startTranscode(const QString& rawInput, const QString& rawOutput, double startTime,
                                             double endTime, const QString& profileJson) {
    QString input = QDir::cleanPath(rawInput);
    QString output = QDir::cleanPath(rawOutput);
    killTranscodeProcess(m_currentTranscode);

    setTranscodeOutput({});
    setTranscoding(true);

    QJsonDocument doc = QJsonDocument::fromJson(profileJson.toUtf8());
    QStringList args = doc.isArray() ? jsonArgsToStringList(profileJson.toUtf8())
                                     : buildArgsFromProfile(input, output, startTime, endTime, profileJson);
    if (doc.isObject() && args.isEmpty()) {
        setTranscodeOutput(tr("Error: failed to build ffmpeg command from profile"));
        setTranscoding(false);
        return "failed";
    }
    if (args.isEmpty()) {
        setTranscodeOutput(tr("Error: profile produced no ffmpeg arguments"));
        setTranscoding(false);
        return "failed";
    }

    appendTranscodeOutput("ffmpeg " + args.join(" ") + "\n\n");

    m_currentTranscode = std::make_unique<QProcess>();
    connectOutputCapture(m_currentTranscode.get());
    m_currentTranscode->start("ffmpeg", args);
    return "started";
}

void GuineaMpegBackendExt::cancelTranscode() {
    if (!m_currentTranscode)
        return;
    killTranscodeProcess(m_currentTranscode);
    appendTranscodeOutput(tr("\n--- Transcoding cancelled ---\n"));
    setTranscoding(false);
}

QString GuineaMpegBackendExt::startPreview(const QString& rawInput, const QString& profileJson, double startTimeMs,
                                           double durationMs, const QString& extension) {
    QString input = QDir::cleanPath(rawInput);
    QString ext = extension.isEmpty() ? QStringLiteral("mkv") : extension;
    static quint64 s_previewCounter = 0;
    QString output = QDir::cleanPath(QDir::tempPath() + QStringLiteral("/guinea_mpeg_preview_") +
                                     QString::number(++s_previewCounter) + "." + ext);

    killTranscodeProcess(m_currentPreview);
    setPreviewGenerating(true);
    m_lastPreviewPath.clear();
    m_lastPreviewSize = 0;
    emit lastPreviewPathChanged();
    emit lastPreviewSizeChanged();

    double startTime = startTimeMs / 1000.0;
    double endTime = (startTimeMs + durationMs) / 1000.0;

    QStringList args = buildArgsFromProfile(input, output, startTime, endTime, profileJson);
    if (args.isEmpty()) {
        setPreviewGenerating(false);
        emit previewFailed();
        return "failed";
    }

    m_currentPreview = std::make_unique<QProcess>();
    QProcess* proc = m_currentPreview.get();
    connect(proc, &QProcess::finished, this, [this, proc, output](int exitCode, QProcess::ExitStatus) {
        releaseProcess(m_currentPreview, proc);
        setPreviewGenerating(false);
        if (exitCode == 0) {
            m_lastPreviewPath = output;
            m_lastPreviewSize = QFileInfo(output).size();
            emit lastPreviewPathChanged();
            emit lastPreviewSizeChanged();
            emit previewGenerated(output);
        } else {
            m_lastPreviewPath.clear();
            m_lastPreviewSize = 0;
            emit lastPreviewPathChanged();
            emit lastPreviewSizeChanged();
            emit previewFailed();
        }
    });
    m_currentPreview->start("ffmpeg", args);
    return "started";
}

void GuineaMpegBackendExt::cancelPreview() {
    if (!m_currentPreview)
        return;
    killTranscodeProcess(m_currentPreview);
    setPreviewGenerating(false);
}

void GuineaMpegBackendExt::sendNotification(const QString& title, const QString& body) {
#ifdef Q_OS_LINUX
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
        QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("Notify"));
    msg.setArguments({QStringLiteral("GuineaMPEG"), 0u, QStringLiteral("guinea-mpeg"), title, body, QStringList(),
                      QVariantMap(), 5000});
    QDBusConnection::sessionBus().asyncCall(msg);
#elif defined(Q_OS_WIN)
    if (m_trayIcon)
        m_trayIcon->showMessage(title, body, QSystemTrayIcon::Information, 5000);
#endif
}

void GuineaMpegBackendExt::appendTranscodeOutput(const QString& chunk) {
    if (chunk.isEmpty())
        return;
    m_transcodeOutput.reserve(m_transcodeOutput.size() + chunk.size());
    m_transcodeOutput += chunk;
    emit transcodeOutputUpdated();
}

void GuineaMpegBackendExt::connectOutputCapture(QProcess* proc) {
    connect(proc, &QProcess::readyReadStandardError, this,
            [this, proc]() { appendTranscodeOutput(QString::fromUtf8(proc->readAllStandardError())); });
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0)
            appendTranscodeOutput(tr("\n--- Transcoding finished: SUCCESS ---\n"));
        else
            appendTranscodeOutput(tr("\n--- Transcoding finished: FAILED (exit code %1) ---\n").arg(exitCode));
        sendNotification(exitCode == 0 ? tr("Transcoding Complete") : tr("Transcoding Failed"),
                         exitCode == 0 ? tr("Your video has been transcoded successfully.")
                                       : tr("Transcoding exited with code %1").arg(exitCode));
        emit transcodeFinished(exitCode == 0);
        setTranscoding(false);
        releaseProcess(m_currentTranscode, proc);
    });
}
