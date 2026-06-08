#include "backend.h"
#include "guinea_mpeg_core.h"
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

GuineaMpegBackendExt::GuineaMpegBackendExt(QObject* parent)
    : QObject(parent) {}

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
        for (const auto& s : root["streams"].toArray()) {
            QJsonObject stream = s.toObject();
            QString type = stream["codec_type"].toString();
            if (type == "video") {
                info["width"] = stream["width"].toInt();
                info["height"] = stream["height"].toInt();
                info["codec"] = stream["codec_name"].toString();
                info["fps"] = stream["r_frame_rate"].toString();
                info["bitrate"] = (qint64)stream["bit_rate"].toString().toULongLong();
            } else if (type == "audio" && !info.contains("audio_codec")) {
                info["audio_codec"] = stream["codec_name"].toString();
            }
        }
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

QString GuineaMpegBackendExt::generatePreview(const QString& rawPath, qint64 timeMs) {
    const char* path = guinea_mpeg_generate_preview(rawPath.toUtf8().constData(), (long long)timeMs);
    if (!path) return {};
    QString result = QString::fromUtf8(path);
    guinea_mpeg_free_string(path);
    return result;
}

QString GuineaMpegBackendExt::startTranscode(const QString& rawInput, const QString& rawOutput,
                                              double startTime, double endTime,
                                              const QString& profileJson) {
    QString input = QDir::cleanPath(rawInput);
    QString output = QDir::cleanPath(rawOutput);
    if (m_currentTranscode) {
        m_currentTranscode->kill();
        m_currentTranscode->waitForFinished(3000);
        m_currentTranscode->deleteLater();
        m_currentTranscode = nullptr;
    }

    setTranscodeOutput({});
    setTranscoding(true);

    QStringList args;
    QJsonDocument doc = QJsonDocument::fromJson(profileJson.toUtf8());
    if (doc.isArray())
        for (const auto& arg : doc.array())
            args << arg.toString();
    else {
        const char* jsonArgs = guinea_mpeg_build_ffmpeg_command(
            input.toUtf8().constData(),
            output.toUtf8().constData(),
            startTime, endTime,
            profileJson.toUtf8().constData()
        );
        if (!jsonArgs) {
            setTranscodeOutput("Error: failed to build ffmpeg command from profile");
            setTranscoding(false);
            return "failed";
        }
        QJsonDocument profDoc = QJsonDocument::fromJson(QByteArray(jsonArgs));
        if (profDoc.isArray())
            for (const auto& arg : profDoc.array())
                args << arg.toString();
        guinea_mpeg_free_string(jsonArgs);
        if (args.isEmpty()) {
            setTranscodeOutput("Error: profile produced no ffmpeg arguments");
            setTranscoding(false);
            return "failed";
        }
    }
    setTranscodeOutput(transcodeOutput() + "ffmpeg " + args.join(" ") + "\n\n");

    m_currentTranscode = new QProcess(this);
    connectOutputCapture();
    m_currentTranscode->start("ffmpeg", args);
    return "started";
}

void GuineaMpegBackendExt::cancelTranscode() {
    if (!m_currentTranscode) return;
    m_currentTranscode->disconnect();
    m_currentTranscode->kill();
    m_currentTranscode->waitForFinished(3000);
    setTranscodeOutput(transcodeOutput() + "\n--- Transcoding cancelled ---\n");
    setTranscoding(false);
    m_currentTranscode->deleteLater();
    m_currentTranscode = nullptr;
}

void GuineaMpegBackendExt::connectOutputCapture() {
    connect(m_currentTranscode, &QProcess::readyReadStandardError, this, [this]() {
        setTranscodeOutput(transcodeOutput() + QString::fromUtf8(m_currentTranscode->readAllStandardError()));
    });
    connect(m_currentTranscode, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0)
            setTranscodeOutput(transcodeOutput() + "\n--- Transcoding finished: SUCCESS ---\n");
        else
            setTranscodeOutput(transcodeOutput() + "\n--- Transcoding finished: FAILED (exit code "
                + QString::number(exitCode) + ") ---\n");
        emit transcodeFinished(exitCode == 0);
        setTranscoding(false);
        m_currentTranscode->deleteLater();
        m_currentTranscode = nullptr;
    });
}
