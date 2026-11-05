#include "backend.h"
#include "guinea_mpeg_core.h"
#include <QApplication>
#include <QClipboard>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QThreadPool>
#ifdef Q_OS_LINUX
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#endif
#ifdef Q_OS_WIN
#include <QIcon>
#endif

namespace {

constexpr int kKillTimeoutMs = 3000;
constexpr int kNotificationTimeoutMs = 5000;
constexpr int kMaxLogLines = 5000;

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
    proc->waitForFinished(kKillTimeoutMs);
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
    m["bitrate"] = jsonInt64(stream["bit_rate"]);
    return m;
}

QVariantMap makeAudioStreamMap(int idx, const QJsonObject& stream) {
    const QJsonObject tags = stream["tags"].toObject();
    QVariantMap m;
    m["index"] = idx;
    m["codec"] = stream["codec_name"].toString();
    m["channels"] = stream["channels"].toInt();
    m["sample_rate"] = stream["sample_rate"].toString();
    m["bitrate"] = jsonInt64(stream["bit_rate"]);
    m["language"] = tags["language"].toString();
    m["title"] = tags["title"].toString();
    return m;
}

QJsonObject parseProbeRoot(const char* json) {
    QJsonObject root = QJsonDocument::fromJson(QByteArray(json)).object();
    guinea_mpeg_free_string(json);
    return root;
}

void collectStreams(const QJsonArray& streams, QVariantMap& info, QVariantList& videoStreams,
                    QVariantList& audioStreams) {
    int videoTypeIdx = 0;
    int audioTypeIdx = 0;
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

void GuineaMpegBackendExt::setTranscodeError(const QString& v) {
    if (m_transcodeError == v)
        return;
    m_transcodeError = v;
    emit transcodeErrorChanged();
}

void GuineaMpegBackendExt::setTranscoding(bool v) {
    m_transcoding = v;
    emit transcodingChanged();
}

QString GuineaMpegBackendExt::extractTranscodeError(const QString& output) const {
    const QStringList lines = output.split('\n');
    QStringList candidates;
    // First pass: lines containing error keywords (most relevant)
    for (int i = lines.size() - 1; i >= 0 && candidates.size() < 3; --i) {
        const QString trimmed = lines[i].trimmed();
        if (trimmed.isEmpty())
            continue;
        if (trimmed.contains("--- Transcoding finished"))
            continue;
        const QString lower = trimmed.toLower();
        const bool isError = lower.contains("error") || lower.contains("invalid") || lower.contains("failed") ||
                             lower.contains("unable") || lower.contains("no such") || lower.contains("unknown") ||
                             lower.contains("not found") || lower.contains("cannot") ||
                             lower.contains("conversion failed");
        if (isError) {
            candidates.prepend(trimmed);
        }
    }
    if (!candidates.isEmpty()) {
        return candidates.join('\n');
    }
    // Fallback: last 2 non-empty, non-banner lines
    QStringList fallback;
    for (int i = lines.size() - 1; i >= 0 && fallback.size() < 2; --i) {
        const QString trimmed = lines[i].trimmed();
        if (trimmed.isEmpty())
            continue;
        if (trimmed.contains("--- Transcoding finished"))
            continue;
        if (trimmed.startsWith("ffmpeg "))
            continue;
        fallback.prepend(trimmed);
    }
    return fallback.join('\n');
}

void GuineaMpegBackendExt::setPreviewGenerating(bool v) {
    m_previewGenerating = v;
    emit previewGeneratingChanged();
}

void GuineaMpegBackendExt::resetPreview() {
    bool changed = !m_lastPreviewPath.isEmpty() || m_lastPreviewSize != 0 || !m_lastPreviewError.isEmpty();
    if (!changed)
        return;
    m_lastPreviewPath.clear();
    m_lastPreviewSize = 0;
    m_previewStderr.clear();
    m_lastPreviewError.clear();
    emit lastPreviewPathChanged();
    emit lastPreviewSizeChanged();
    emit lastPreviewErrorChanged();
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

QString GuineaMpegBackendExt::computeNormalizeGain(const QString& rawInput, double startTime, double endTime,
                                                   const QString& profileJson) {
    QString input = QDir::cleanPath(rawInput);
    return takeRustString(guinea_mpeg_compute_normalize_gain(input.toUtf8().constData(), startTime, endTime,
                                                             profileJson.toUtf8().constData()),
                          QStringLiteral("{}"));
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
    const QJsonObject root = parseProbeRoot(json);
    info["duration"] = jsonDouble(root["format"].toObject()["duration"]);
    QVariantList videoStreams;
    QVariantList audioStreams;
    collectStreams(root["streams"].toArray(), info, videoStreams, audioStreams);
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

static bool normalizeRequested(const QJsonDocument& doc) {
    if (!doc.isObject())
        return false;
    const QJsonObject af = doc.object().value(QStringLiteral("audio_filters")).toObject();
    return af.value(QStringLiteral("normalize")).toBool(false);
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

    if (m_transcodeOutput.isEmpty()) {
        setTranscodeOutput({});
    } else {
        appendTranscodeOutput("\n\n" + tr("===== Job: %1 \u2192 %2 =====").arg(input).arg(output) + "\n\n");
    }
    setTranscodeError({});
    setTranscoding(true);

    const QJsonDocument doc = QJsonDocument::fromJson(profileJson.toUtf8());
    if (normalizeRequested(doc)) {
        beginNormalizeAnalysis(input, output, startTime, endTime, profileJson);
    } else {
        launchTranscode(input, output, startTime, endTime, profileJson);
    }
    return "started";
}

void GuineaMpegBackendExt::cancelTranscode() {
    if (!m_currentTranscode) {
        if (m_analysisToken != 0) {
            m_analysisToken++; // analysis in flight (no process yet): drop its pending launch
            appendTranscodeOutput(tr("\n--- Transcoding cancelled ---\n"));
            setTranscoding(false);
        }
        return;
    }
    killTranscodeProcess(m_currentTranscode);
    appendTranscodeOutput(tr("\n--- Transcoding cancelled ---\n"));
    setTranscoding(false);
}

void GuineaMpegBackendExt::beginNormalizeAnalysis(const QString& input, const QString& output, double startTime,
                                                  double endTime, const QString& profileJson) {
    const int token = ++m_analysisToken;
    appendTranscodeOutput(tr("Analyzing audio for normalization (first pass)...\n"));
    QPointer<GuineaMpegBackendExt> self(this);
    QThreadPool::globalInstance()->start([self, token, input, output, startTime, endTime, profileJson] {
        const char* json = guinea_mpeg_compute_normalize_gain(input.toUtf8().constData(), startTime, endTime,
                                                              profileJson.toUtf8().constData());
        const QString resultJson = takeRustString(json, QStringLiteral("{}"));
        if (self.isNull())
            return;
        QMetaObject::invokeMethod(
            self,
            [self, token, resultJson, input, output, startTime, endTime, profileJson] {
                self->finishNormalizeAnalysis(token, resultJson, input, output, startTime, endTime, profileJson);
            },
            Qt::QueuedConnection);
    });
}

void GuineaMpegBackendExt::finishNormalizeAnalysis(int token, const QString& resultJson, const QString& input,
                                                   const QString& output, double startTime, double endTime,
                                                   const QString& profileJson) {
    if (token != m_analysisToken)
        return; // superseded by cancel or a newer run
    m_analysisToken = 0;

    const QJsonObject gainObj = QJsonDocument::fromJson(resultJson.toUtf8()).object();
    if (!gainObj.contains(QStringLiteral("gain"))) {
        QString detail = gainObj.value(QStringLiteral("error")).toString();
        if (detail.isEmpty())
            detail = tr("no analysis result");
        failTranscode(tr("Error: normalization analysis failed: %1").arg(detail));
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(profileJson.toUtf8());
    QJsonObject profile = doc.object();
    QJsonObject af = profile.value(QStringLiteral("audio_filters")).toObject();
    af[QStringLiteral("gain_db")] = gainObj.value(QStringLiteral("gain")).toDouble();
    af[QStringLiteral("normalize")] = false;
    profile[QStringLiteral("audio_filters")] = af;
    launchTranscode(input, output, startTime, endTime,
                    QString::fromUtf8(QJsonDocument(profile).toJson(QJsonDocument::Compact)));
}

void GuineaMpegBackendExt::launchTranscode(const QString& input, const QString& output, double startTime,
                                           double endTime, const QString& profileJson) {
    const QJsonDocument doc = QJsonDocument::fromJson(profileJson.toUtf8());
    const QStringList args = doc.isArray() ? jsonArgsToStringList(profileJson.toUtf8())
                                           : buildArgsFromProfile(input, output, startTime, endTime, profileJson);
    if (doc.isObject() && args.isEmpty()) {
        failTranscode(tr("Error: failed to build ffmpeg command from profile"));
        return;
    }
    if (args.isEmpty()) {
        failTranscode(tr("Error: profile produced no ffmpeg arguments"));
        return;
    }

    appendTranscodeOutput("ffmpeg " + args.join(" ") + "\n\n");

    m_currentTranscode = std::make_unique<QProcess>();
    connectOutputCapture(m_currentTranscode.get());
    m_currentTranscode->start("ffmpeg", args);
}

void GuineaMpegBackendExt::clearTranscodeOutput() {
    setTranscodeOutput({});
    setTranscodeError({});
}

QString GuineaMpegBackendExt::startPreview(const QString& rawInput, const QString& profileJson, double startTimeMs,
                                           double durationMs, const QString& extension) {
    QString input = QDir::cleanPath(rawInput);
    QString ext = extension.isEmpty() ? QStringLiteral("mkv") : extension;
    // One fixed preview file per format; per-run names only pile up in temp.
    QString output = QDir::cleanPath(QDir::tempPath() + QStringLiteral("/guinea_mpeg_preview.") + ext);

    killTranscodeProcess(m_currentPreview);
    setPreviewGenerating(true);
    m_lastPreviewPath.clear();
    m_lastPreviewSize = 0;
    m_previewStderr.clear();
    m_lastPreviewError.clear();
    emit lastPreviewPathChanged();
    emit lastPreviewSizeChanged();
    emit lastPreviewErrorChanged();

    double startTime = startTimeMs / 1000.0;
    double endTime = (startTimeMs + durationMs) / 1000.0;

    m_lastPreviewDurationMs = (qint64)durationMs;
    emit lastPreviewDurationMsChanged();

    QString previewProfileJson = profileJson;
    QJsonDocument previewDoc = QJsonDocument::fromJson(profileJson.toUtf8());
    if (previewDoc.isObject()) {
        QJsonObject profile = previewDoc.object();
        QJsonObject af = profile.value(QStringLiteral("audio_filters")).toObject();
        if (af.value(QStringLiteral("normalize")).toBool(false)) {
            af[QStringLiteral("normalize")] = false;
            profile[QStringLiteral("audio_filters")] = af;
            previewProfileJson = QJsonDocument(profile).toJson(QJsonDocument::Compact);
        }
    }

    QStringList args = buildArgsFromProfile(input, output, startTime, endTime, previewProfileJson);
    if (args.isEmpty()) {
        setPreviewGenerating(false);
        emit previewFailed();
        return "failed";
    }

    m_currentPreview = std::make_unique<QProcess>();
    QProcess* proc = m_currentPreview.get();
    connect(proc, &QProcess::readyReadStandardError, this, [this, proc]() {
        m_previewStderr += QString::fromUtf8(proc->readAllStandardError());
        // Errors are at the end of ffmpeg's stderr; keep only the tail
        const int max = 16384;
        if (m_previewStderr.size() > max)
            m_previewStderr = m_previewStderr.right(max);
        emit previewOutputUpdated();
    });
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
            const QString err = extractTranscodeError(m_previewStderr);
            m_lastPreviewError = err.isEmpty() ? tr("Unknown error (exit code %1)").arg(exitCode) : err;
            emit lastPreviewPathChanged();
            emit lastPreviewSizeChanged();
            emit lastPreviewErrorChanged();
            emit previewFailed();
        }
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        releaseProcess(m_currentPreview, proc);
        setPreviewGenerating(false);
        m_lastPreviewError = tr("Failed to start ffmpeg");
        emit lastPreviewErrorChanged();
        emit previewFailed();
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

QString GuineaMpegBackendExt::chooseOutputDirectory(const QString& startDir) {
    return QFileDialog::getExistingDirectory(nullptr, tr("Select Output Directory"), startDir);
}

void GuineaMpegBackendExt::sendNotification(const QString& title, const QString& body) {
#ifdef Q_OS_LINUX
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
        QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("Notify"));
    msg.setArguments({QStringLiteral("GuineaMPEG"), 0u, QStringLiteral("guinea-mpeg"), title, body, QStringList(),
                      QVariantMap(), kNotificationTimeoutMs});
    QDBusConnection::sessionBus().asyncCall(msg);
#elif defined(Q_OS_WIN)
    if (m_trayIcon)
        m_trayIcon->showMessage(title, body, QSystemTrayIcon::Information, kNotificationTimeoutMs);
#endif
}

void GuineaMpegBackendExt::appendTranscodeOutput(const QString& chunk) {
    if (chunk.isEmpty())
        return;
    m_transcodeOutput.reserve(m_transcodeOutput.size() + chunk.size());
    m_transcodeOutput += chunk;
    const int lineCount = m_transcodeOutput.count('\n');
    if (lineCount > kMaxLogLines) {
        const QStringList lines = m_transcodeOutput.split('\n');
        const int keep = kMaxLogLines - 1;
        QStringList kept = lines.mid(lines.size() - keep);
        // Avoid stacking notices: if the oldest kept line is already a truncation notice, drop it
        if (!kept.isEmpty() && kept.first().startsWith("[log truncated"))
            kept.removeFirst();
        kept.prepend(tr("[log truncated - showing last %1 lines]").arg(kMaxLogLines));
        m_transcodeOutput = kept.join('\n');
    }
    emit transcodeOutputUpdated();
}

void GuineaMpegBackendExt::connectOutputCapture(QProcess* proc) {
    connect(proc, &QProcess::readyReadStandardError, this,
            [this, proc]() { appendTranscodeOutput(QString::fromUtf8(proc->readAllStandardError())); });
    connect(proc, &QProcess::readyReadStandardOutput, this,
            [this, proc]() { appendTranscodeOutput(QString::fromUtf8(proc->readAllStandardOutput())); });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        appendTranscodeOutput(tr("\n--- Transcoding finished: FAILED (could not start ffmpeg) ---\n"));
        setTranscodeError(tr("Failed to start ffmpeg"));
        finishTranscode(proc, false);
    });
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0) {
            appendTranscodeOutput(tr("\n--- Transcoding finished: SUCCESS ---\n"));
            setTranscodeError({});
        } else {
            appendTranscodeOutput(tr("\n--- Transcoding finished: FAILED (exit code %1) ---\n").arg(exitCode));
            const QString err = extractTranscodeError(m_transcodeOutput);
            if (!err.isEmpty()) {
                appendTranscodeOutput(tr("Detected error details:\n") + err + "\n");
                setTranscodeError(err);
            } else {
                setTranscodeError(tr("Unknown error (exit code %1)").arg(exitCode));
            }
        }
        finishTranscode(proc, exitCode == 0);
    });
}

void GuineaMpegBackendExt::finishTranscode(QProcess* proc, bool success) {
    // Release before notifying QML: onTranscodingChanged starts the next job,
    // which would otherwise kill/delete the QProcess emitting this signal.
    releaseProcess(m_currentTranscode, proc);
    emit transcodeFinished(success);
    setTranscoding(false);
}

QString GuineaMpegBackendExt::failTranscode(const QString& msg) {
    appendTranscodeOutput(msg + "\n");
    setTranscodeError(msg);
    setTranscoding(false);
    return QStringLiteral("failed");
}
