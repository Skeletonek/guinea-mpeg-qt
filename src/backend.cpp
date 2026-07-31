#include "backend.h"
#include "guinea_mpeg_core.h"
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#ifdef Q_OS_LINUX
#include <QDBusMessage>
#include <QDBusConnection>
#include <QDBusPendingCall>
#endif
#ifdef Q_OS_WIN
#include <QIcon>
#endif

GuineaMpegBackendExt::GuineaMpegBackendExt(QObject* parent)
    : QObject(parent) {
#ifdef Q_OS_WIN
    m_trayIcon = new QSystemTrayIcon(this);
    m_trayIcon->setIcon(QIcon(QStringLiteral(":/media/logo/logo.png")));
#endif
}

GuineaMpegBackendExt::~GuineaMpegBackendExt() {
    if (m_currentTranscode) {
        m_currentTranscode->kill();
        m_currentTranscode->waitForFinished(3000);
    }
}

void GuineaMpegBackendExt::setTranscodeOutput(const QString& v) {
    m_transcodeOutput = v;
    emit transcodeOutputUpdated();
}

void GuineaMpegBackendExt::setTranscoding(bool v) {
    m_transcoding = v;
    emit transcodingChanged();
}

QString GuineaMpegBackendExt::defaultProfileNames() {
    const char* json = guinea_mpeg_default_profile_names();
    QString result = QString::fromUtf8(json);
    guinea_mpeg_free_string(json);
    return result;
}

QString GuineaMpegBackendExt::availableProfiles() {
    const char* json = guinea_mpeg_available_profiles();
    QString result = QString::fromUtf8(json);
    guinea_mpeg_free_string(json);
    return result;
}

QString GuineaMpegBackendExt::loadProfile(const QString& name) {
    const char* json = guinea_mpeg_load_profile(name.toUtf8().constData());
    QString result = QString::fromUtf8(json);
    guinea_mpeg_free_string(json);
    return result;
}

bool GuineaMpegBackendExt::saveProfile(const QString& name, const QString& json) {
    return guinea_mpeg_save_profile(name.toUtf8().constData(), json.toUtf8().constData());
}

QString GuineaMpegBackendExt::availableEncoders() {
    const char* result = guinea_mpeg_available_encoders();
    if (!result) return "null";
    QString json = QString::fromUtf8(result);
    guinea_mpeg_free_string(result);
    return json;
}

QString GuineaMpegBackendExt::encoderCapabilities(const QString& encoderName) {
    const char* result = guinea_mpeg_encoder_capabilities(encoderName.toUtf8().constData());
    if (!result) return "null";
    QString json = QString::fromUtf8(result);
    guinea_mpeg_free_string(result);
    return json;
}

QString GuineaMpegBackendExt::generateCommandPreview(const QString& json) {
    const char* result = guinea_mpeg_preview_command(json.toUtf8().constData());
    if (!result) return {};
    QString preview = QString::fromUtf8(result);
    guinea_mpeg_free_string(result);
    return preview;
}

bool GuineaMpegBackendExt::deleteProfile(const QString& name) {
    return guinea_mpeg_delete_profile(name.toUtf8().constData());
}

bool GuineaMpegBackendExt::restoreDefaultProfiles() {
    return guinea_mpeg_restore_defaults();
}

QVariantMap GuineaMpegBackendExt::getVideoInfo(const QString& rawPath) {
    const char* json = guinea_mpeg_video_info(rawPath.toUtf8().constData());
    QVariantMap info;
    if (json) {
        QJsonObject root = QJsonDocument::fromJson(QByteArray(json)).object();
        info["duration"] = root["format"].toObject()["duration"].toString().toDouble();
        QVariantList videoStreams;
        QVariantList audioStreams;
        int videoTypeIdx = 0;
        int audioTypeIdx = 0;
        for (const auto& s : root["streams"].toArray()) {
            QJsonObject stream = s.toObject();
            QString type = stream["codec_type"].toString();
            if (type == "video") {
                info["width"] = stream["width"].toInt();
                info["height"] = stream["height"].toInt();
                info["codec"] = stream["codec_name"].toString();
                info["fps"] = stream["r_frame_rate"].toString();
                info["bitrate"] = (qint64)stream["bit_rate"].toString().toULongLong();
                QVariantMap vs;
                vs["index"] = videoTypeIdx++;
                vs["codec"] = stream["codec_name"].toString();
                vs["width"] = stream["width"].toInt();
                vs["height"] = stream["height"].toInt();
                vs["fps"] = stream["r_frame_rate"].toString();
                videoStreams.append(vs);
            } else if (type == "audio") {
                if (!info.contains("audio_codec"))
                    info["audio_codec"] = stream["codec_name"].toString();
                QVariantMap as;
                as["index"] = audioTypeIdx++;
                as["codec"] = stream["codec_name"].toString();
                as["channels"] = stream["channels"].toInt();
                as["sample_rate"] = stream["sample_rate"].toString();
                as["language"] = stream["tags"].toObject()["language"].toString();
                audioStreams.append(as);
            }
        }
        info["video_streams"] = videoStreams;
        info["audio_streams"] = audioStreams;
        guinea_mpeg_free_string(json);
    } else
        info["duration"] = 0.0;
    return info;
}

bool GuineaMpegBackendExt::ffmpegAvailable() {
    return guinea_mpeg_ffmpeg_available();
}

QString GuineaMpegBackendExt::getFfmpegVersion() {
    const char* ver = guinea_mpeg_ffmpeg_version();
    if (!ver) return {};
    QString result = QString::fromUtf8(ver);
    guinea_mpeg_free_string(ver);
    return result;
}

QString GuineaMpegBackendExt::getMpvVersion() {
    const char* ver = guinea_mpeg_mpv_version();
    if (!ver) return {};
    QString result = QString::fromUtf8(ver);
    guinea_mpeg_free_string(ver);
    return result;
}

QString GuineaMpegBackendExt::generatePreview(const QString& rawPath, qint64 timeMs) {
    const char* path = guinea_mpeg_generate_preview(rawPath.toUtf8().constData(), (long long)timeMs);
    if (!path) return {};
    QString result = QString::fromUtf8(path);
    guinea_mpeg_free_string(path);
    return result;
}

static void killTranscodeProcess(QProcess*& proc) {
    if (!proc) return;
    proc->disconnect();
    proc->kill();
    proc->waitForFinished(3000);
    if (proc) {
        proc->deleteLater();
        proc = nullptr;
    }
}

static QStringList parseArgsFromArray(const QString& json) {
    QStringList args;
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (doc.isArray())
        for (const auto& arg : doc.array())
            args << arg.toString();
    return args;
}

static QStringList buildArgsFromProfile(const QString& input, const QString& output,
                                         double startTime, double endTime,
                                         const QString& profileJson) {
    const char* jsonArgs = guinea_mpeg_build_ffmpeg_command(
        input.toUtf8().constData(),
        output.toUtf8().constData(),
        startTime, endTime,
        profileJson.toUtf8().constData()
    );
    if (!jsonArgs) return {};
    QStringList args;
    QJsonDocument profDoc = QJsonDocument::fromJson(QByteArray(jsonArgs));
    if (profDoc.isArray())
        for (const auto& arg : profDoc.array())
            args << arg.toString();
    guinea_mpeg_free_string(jsonArgs);
    return args;
}

QString GuineaMpegBackendExt::startTranscode(const QString& rawInput, const QString& rawOutput,
                                              double startTime, double endTime,
                                              const QString& profileJson) {
    QString input = QDir::cleanPath(rawInput);
    QString output = QDir::cleanPath(rawOutput);
    killTranscodeProcess(m_currentTranscode);

    setTranscodeOutput({});
    setTranscoding(true);

    QJsonDocument doc = QJsonDocument::fromJson(profileJson.toUtf8());
    QStringList args = doc.isArray()
        ? parseArgsFromArray(profileJson)
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

    setTranscodeOutput(transcodeOutput() + "ffmpeg " + args.join(" ") + "\n\n");

    m_currentTranscode = new QProcess(this);
    connectOutputCapture();
    m_currentTranscode->start("ffmpeg", args);
    return "started";
}

void GuineaMpegBackendExt::cancelTranscode() {
    if (!m_currentTranscode) return;
    killTranscodeProcess(m_currentTranscode);
    setTranscodeOutput(transcodeOutput() + tr("\n--- Transcoding cancelled ---\n"));
    setTranscoding(false);
}

void GuineaMpegBackendExt::sendNotification(const QString& title, const QString& body) {
#ifdef Q_OS_LINUX
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("/org/freedesktop/Notifications"),
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("Notify")
    );
    msg.setArguments({
        QStringLiteral("GuineaMPEG"),
        0u,
        QStringLiteral("guinea-mpeg"),
        title,
        body,
        QStringList(),
        QVariantMap(),
        5000
    });
    QDBusConnection::sessionBus().asyncCall(msg);
#elif defined(Q_OS_WIN)
    if (m_trayIcon)
        m_trayIcon->showMessage(title, body, QSystemTrayIcon::Information, 5000);
#endif
}

void GuineaMpegBackendExt::connectOutputCapture() {
    connect(m_currentTranscode, &QProcess::readyReadStandardError, this, [this]() {
        if (m_currentTranscode)
            setTranscodeOutput(transcodeOutput() + QString::fromUtf8(m_currentTranscode->readAllStandardError()));
    });
    connect(m_currentTranscode, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0)
            setTranscodeOutput(transcodeOutput() + tr("\n--- Transcoding finished: SUCCESS ---\n"));
        else
            setTranscodeOutput(transcodeOutput() + tr("\n--- Transcoding finished: FAILED (exit code %1) ---\n").arg(exitCode));
        sendNotification(
            exitCode == 0 ? tr("Transcoding Complete") : tr("Transcoding Failed"),
            exitCode == 0 ? tr("Your video has been transcoded successfully.")
                          : tr("Transcoding exited with code %1").arg(exitCode)
        );
        emit transcodeFinished(exitCode == 0);
        setTranscoding(false);
        m_currentTranscode->deleteLater();
        m_currentTranscode = nullptr;
    });
}
