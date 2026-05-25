#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QDebug>
#include <QSGRendererInterface>
#include <clocale>
#include "mpvitem.h"
#include <QProcess>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDir>
#include <QUrl>
#include <dlfcn.h>

// Function pointer types for Rust library
using InitCoreFn = bool(*)();
using AvailableProfilesFn = char*(*)();
using LoadProfileFn = char*(*)(const char*);
using SaveProfileFn = bool(*)(const char*, const char*);
using DeleteProfileFn = bool(*)(const char*);
using BuildFfmpegCommandFn = char*(*)(const char*, const char*, double, double, const char*);
using ParseVideoInfoFn = char*(*)(const char*);
using FreeRustStringFn = void(*)(char*);

class GuineaMpegBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString transcodeOutput READ transcodeOutput NOTIFY transcodeOutputUpdated)
    Q_PROPERTY(bool transcoding READ transcoding NOTIFY transcodingChanged)
public:
    explicit GuineaMpegBackend(QObject* parent = nullptr) : QObject(parent) {
        loadRustLibrary();
    }

    ~GuineaMpegBackend() {
        if (m_currentTranscode) {
            m_currentTranscode->kill();
            m_currentTranscode->waitForFinished(3000);
        }
        if (m_lib) dlclose(m_lib);
    }

    QString transcodeOutput() const { return m_transcodeOutput; }
    bool transcoding() const { return m_transcoding; }

    Q_INVOKABLE QString availableProfiles() {
        if (!m_availableProfiles) return "[]";
        char* result = m_availableProfiles();
        QString json = QString::fromUtf8(result);
        if (m_freeRustString) m_freeRustString(result);
        return json;
    }

    Q_INVOKABLE QString loadProfile(const QString& name) {
        if (!m_loadProfile) return "{}";
        QByteArray nameBytes = name.toUtf8();
        char* result = m_loadProfile(nameBytes.constData());
        QString json = QString::fromUtf8(result);
        if (m_freeRustString) m_freeRustString(result);
        return json;
    }

    Q_INVOKABLE bool saveProfile(const QString& name, const QString& json) {
        if (!m_saveProfile) return false;
        QByteArray nameBytes = name.toUtf8();
        QByteArray jsonBytes = json.toUtf8();
        return m_saveProfile(nameBytes.constData(), jsonBytes.constData());
    }

    Q_INVOKABLE bool deleteProfile(const QString& name) {
        if (!m_deleteProfile) return false;
        QByteArray nameBytes = name.toUtf8();
        return m_deleteProfile(nameBytes.constData());
    }

    Q_INVOKABLE QVariantMap getVideoInfo(const QString& path) {
        QProcess ffprobe;
        ffprobe.start("ffprobe", {
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            path
        });
        ffprobe.waitForFinished(30000);
        QByteArray output = ffprobe.readAllStandardOutput();

        QJsonDocument doc = QJsonDocument::fromJson(output);
        QJsonObject root = doc.object();
        QVariantMap info;

        // Duration
        QJsonObject format = root["format"].toObject();
        info["duration"] = format["duration"].toString().toDouble();

        // Video stream info
        QJsonArray streams = root["streams"].toArray();
        for (const auto& s : streams) {
            QJsonObject stream = s.toObject();
            if (stream["codec_type"].toString() == "video") {
                info["width"] = stream["width"].toInt();
                info["height"] = stream["height"].toInt();
                info["codec"] = stream["codec_name"].toString();
                info["fps"] = stream["r_frame_rate"].toString();
                info["bitrate"] = (qint64)stream["bit_rate"].toString().toULongLong();
                break;
            }
        }

        return info;
    }

    Q_INVOKABLE bool ffmpegAvailable() {
        QProcess which;
        which.start("which", {"ffmpeg"});
        which.waitForFinished();
        return which.exitCode() == 0;
    }

    Q_INVOKABLE QString getFfmpegVersion() {
        QProcess ffmpeg;
        ffmpeg.start("ffmpeg", {"-version"});
        ffmpeg.waitForFinished(5000);
        return QString::fromUtf8(ffmpeg.readAllStandardOutput().split('\n').first());
    }

    Q_INVOKABLE QString generatePreview(const QString& path, qint64 timeMs) {
        QString tmpDir = QDir::tempPath();
        QString previewPath = tmpDir + "/guinea_mpeg_preview.png";

        QProcess ffmpeg;
        QStringList args;
        args << "-y"
             << "-ss" << QString::number(timeMs / 1000.0, 'f', 3)
             << "-i" << path
             << "-vframes" << "1"
             << "-q:v" << "2"
             << previewPath;
        ffmpeg.start("ffmpeg", args);
        ffmpeg.waitForFinished(30000);

        if (ffmpeg.exitCode() == 0)
            return previewPath;
        return QString();
    }

    Q_INVOKABLE QString startTranscode(const QString& input, const QString& output,
                                        double startTime, double endTime,
                                        const QString& profileJson) {
        if (m_currentTranscode) {
            m_currentTranscode->kill();
            m_currentTranscode->waitForFinished(3000);
            m_currentTranscode->deleteLater();
            m_currentTranscode = nullptr;
        }

        m_transcodeOutput.clear();
        m_transcoding = true;
        emit transcodingChanged();
        emit transcodeOutputUpdated();

        if (!m_buildFfmpegCommand) {
            QStringList fallbackArgs;
            if (startTime > 0) {
                fallbackArgs << "-ss" << QString::number(startTime, 'f', 3);
            }
            fallbackArgs << "-i" << input;
            if (endTime > startTime) {
                fallbackArgs << "-t" << QString::number(endTime - startTime, 'f', 3);
            }
            fallbackArgs << "-c:v" << "libx264" << "-preset" << "medium"
                 << "-c:a" << "aac" << "-y" << output;

            m_currentTranscode = new QProcess(this);
            connectOutputCapture();
            m_currentTranscode->start("ffmpeg", fallbackArgs);
            return "started";
        }

        QByteArray inputBytes = input.toUtf8();
        QByteArray outputBytes = output.toUtf8();
        QByteArray profileBytes = profileJson.toUtf8();

        char* result = m_buildFfmpegCommand(
            inputBytes.constData(),
            outputBytes.constData(),
            startTime, endTime,
            profileBytes.constData()
        );
        QString json = QString::fromUtf8(result);
        if (m_freeRustString) m_freeRustString(result);

        QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
        QJsonArray argsArray = doc.array();

        QStringList args;
        for (const auto& arg : argsArray)
            args << arg.toString();

        m_transcodeOutput += "ffmpeg " + args.join(" ") + "\n\n";
        emit transcodeOutputUpdated();

        m_currentTranscode = new QProcess(this);
        connectOutputCapture();
        m_currentTranscode->start("ffmpeg", args);
        return "started";
    }

    Q_INVOKABLE void cancelTranscode() {
        if (!m_currentTranscode) return;
        m_currentTranscode->disconnect();
        m_currentTranscode->kill();
        m_currentTranscode->waitForFinished(3000);
        m_transcodeOutput += "\n--- Transcoding cancelled ---\n";
        emit transcodeOutputUpdated();
        m_transcoding = false;
        emit transcodingChanged();
        m_currentTranscode->deleteLater();
        m_currentTranscode = nullptr;
    }

signals:
    void transcodeFinished(bool success);
    void transcodeOutputUpdated();
    void transcodingChanged();

private:
    void connectOutputCapture() {
        connect(m_currentTranscode, &QProcess::readyReadStandardError, this, [this]() {
            m_transcodeOutput += QString::fromUtf8(m_currentTranscode->readAllStandardError());
            emit transcodeOutputUpdated();
        });
        connect(m_currentTranscode, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int exitCode, QProcess::ExitStatus) {
            if (exitCode == 0)
                m_transcodeOutput += "\n--- Transcoding finished: SUCCESS ---\n";
            else
                m_transcodeOutput += "\n--- Transcoding finished: FAILED (exit code "
                    + QString::number(exitCode) + ") ---\n";
            emit transcodeOutputUpdated();
            emit transcodeFinished(exitCode == 0);
            m_transcoding = false;
            emit transcodingChanged();
            m_currentTranscode->deleteLater();
            m_currentTranscode = nullptr;
        });
    }

    QString m_transcodeOutput;
    QProcess* m_currentTranscode = nullptr;
    bool m_transcoding = false;
    void* m_lib = nullptr;
    InitCoreFn m_initCore = nullptr;
    AvailableProfilesFn m_availableProfiles = nullptr;
    LoadProfileFn m_loadProfile = nullptr;
    SaveProfileFn m_saveProfile = nullptr;
    DeleteProfileFn m_deleteProfile = nullptr;
    BuildFfmpegCommandFn m_buildFfmpegCommand = nullptr;
    ParseVideoInfoFn m_parseVideoInfo = nullptr;
    FreeRustStringFn m_freeRustString = nullptr;

    void loadRustLibrary() {
        // Try loading from various paths
        QStringList searchPaths = {
            QCoreApplication::applicationDirPath() + "/libguinea_mpeg_core.so",
            QCoreApplication::applicationDirPath() + "/../rust/target/release/libguinea_mpeg_core.so",
            "libguinea_mpeg_core.so",
        };

        for (const auto& path : searchPaths) {
            m_lib = dlopen(path.toUtf8().constData(), RTLD_LAZY | RTLD_LOCAL);
            if (m_lib) {
                qDebug() << "Loaded Rust library from:" << path;
                break;
            }
        }

        if (!m_lib) {
            qWarning() << "Could not load Rust library. Some features will be unavailable.";
            qWarning() << "dlerror:" << dlerror();
            return;
        }

        // Load function pointers
        m_initCore = (InitCoreFn)dlsym(m_lib, "init_core");
        m_availableProfiles = (AvailableProfilesFn)dlsym(m_lib, "available_profiles");
        m_loadProfile = (LoadProfileFn)dlsym(m_lib, "load_profile");
        m_saveProfile = (SaveProfileFn)dlsym(m_lib, "save_profile");
        m_deleteProfile = (DeleteProfileFn)dlsym(m_lib, "delete_profile");
        m_buildFfmpegCommand = (BuildFfmpegCommandFn)dlsym(m_lib, "build_ffmpeg_command");
        m_parseVideoInfo = (ParseVideoInfoFn)dlsym(m_lib, "parse_video_info");
        m_freeRustString = (FreeRustStringFn)dlsym(m_lib, "free_rust_string");

        if (m_initCore) {
            m_initCore();
            qDebug() << "Rust core initialized successfully";
        }
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");
    QQuickStyle::setStyle("org.kde.desktop");

    // Force OpenGL so QQuickFramebufferObject + mpv_render_context works
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QQmlApplicationEngine engine;

    // Register backend
    qmlRegisterType<GuineaMpegBackend>("GuineaMpeg", 1, 0, "GuineaMpegBackend");
    qmlRegisterType<MpvItem>("GuineaMpeg", 1, 0, "MpvItem");
    auto backend = new GuineaMpegBackend(&app);
    engine.rootContext()->setContextProperty("backend", backend);
    engine.rootContext()->setContextProperty("ffmpegAvailable", QVariant(backend->ffmpegAvailable()));
    engine.rootContext()->setContextProperty("ffmpegVersion", QVariant(backend->getFfmpegVersion()));

    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );
    engine.load(url);

    return app.exec();
}

#include "main.moc"
