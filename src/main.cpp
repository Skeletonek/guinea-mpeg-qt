#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
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
#include <QIcon>
#include <QStandardPaths>
#include <QFile>

#ifdef Q_OS_WIN
#include <windows.h>
#else
#include <dlfcn.h>
#endif

// Function pointer types for Rust library
using InitCoreFn = bool(*)();
using AvailableProfilesFn = char*(*)();
using LoadProfileFn = char*(*)(const char*);
using SaveProfileFn = bool(*)(const char*, const char*);
using DeleteProfileFn = bool(*)(const char*);
using BuildFfmpegCommandFn = char*(*)(const char*, const char*, double, double, const char*);
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
        if (m_lib) {
#ifdef Q_OS_WIN
            FreeLibrary((HMODULE)m_lib);
#else
            dlclose(m_lib);
#endif
        }
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

        // Stream info
        QJsonArray streams = root["streams"].toArray();
        for (const auto& s : streams) {
            QJsonObject stream = s.toObject();
            QString codecType = stream["codec_type"].toString();
            if (codecType == "video") {
                info["width"] = stream["width"].toInt();
                info["height"] = stream["height"].toInt();
                info["codec"] = stream["codec_name"].toString();
                info["fps"] = stream["r_frame_rate"].toString();
                info["bitrate"] = (qint64)stream["bit_rate"].toString().toULongLong();
            } else if (codecType == "audio" && !info.contains("audio_codec")) {
                info["audio_codec"] = stream["codec_name"].toString();
            }
        }

        return info;
    }

    Q_INVOKABLE bool ffmpegAvailable() {
        return !QStandardPaths::findExecutable("ffmpeg").isEmpty();
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
    FreeRustStringFn m_freeRustString = nullptr;

    void loadRustLibrary() {
#ifdef Q_OS_WIN
        QStringList searchPaths = {
            QCoreApplication::applicationDirPath() + "/guinea_mpeg_core.dll",
            QCoreApplication::applicationDirPath() + "/../rust/target/release/guinea_mpeg_core.dll",
            "guinea_mpeg_core.dll",
        };

        for (const auto& path : searchPaths) {
            m_lib = (void*)LoadLibraryA(path.toUtf8().constData());
            if (m_lib) {
                qDebug() << "Loaded Rust library from:" << path;
                break;
            }
        }

        if (!m_lib) {
            qWarning() << "Could not load Rust library. Some features will be unavailable.";
            qWarning() << "LoadLibrary error:" << GetLastError();
            return;
        }

        auto resolve = [&](const char* name) -> void* {
            return (void*)GetProcAddress((HMODULE)m_lib, name);
        };
#else
        QStringList searchPaths = {
            QCoreApplication::applicationDirPath() + "/libguinea_mpeg_core.so",
            QCoreApplication::applicationDirPath() + "/../rust/target/release/libguinea_mpeg_core.so",
            QCoreApplication::applicationDirPath() + "/../lib/guinea-mpeg/libguinea_mpeg_core.so",
            "/usr/local/lib/guinea-mpeg/libguinea_mpeg_core.so",
            "/usr/lib/guinea-mpeg/libguinea_mpeg_core.so",
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

        auto resolve = [&](const char* name) -> void* {
            return dlsym(m_lib, name);
        };
#endif

        // Load function pointers
        m_initCore = (InitCoreFn)resolve("init_core");
        m_availableProfiles = (AvailableProfilesFn)resolve("available_profiles");
        m_loadProfile = (LoadProfileFn)resolve("load_profile");
        m_saveProfile = (SaveProfileFn)resolve("save_profile");
        m_deleteProfile = (DeleteProfileFn)resolve("delete_profile");
        m_buildFfmpegCommand = (BuildFfmpegCommandFn)resolve("build_ffmpeg_command");
        m_freeRustString = (FreeRustStringFn)resolve("free_rust_string");

        if (m_initCore)
            m_initCore();
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
#ifdef Q_OS_LINUX
    app.setDesktopFileName("guinea-mpeg");
    app.setWindowIcon(QIcon::fromTheme("guinea-mpeg"));
#endif
    std::setlocale(LC_NUMERIC, "C");

    // Force OpenGL so QQuickFramebufferObject + mpv_render_context works
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    // Build info for the About dialog
    QVariantMap buildInfo;
    buildInfo["author"] = "Skeletonek";
    buildInfo["license"] = "BSD 3-Clause";
    buildInfo["version"] = PROJECT_VERSION;
    buildInfo["buildDate"] = __DATE__ " " __TIME__;
    buildInfo["packageTarget"] = PACKAGE_TARGET;
#ifdef Q_OS_LINUX
    buildInfo["distroName"] = []() -> QString {
        QFile f("/etc/os-release");
        if (!f.open(QIODevice::ReadOnly))
            return "Unknown";
        while (!f.atEnd()) {
            QString line = QString::fromUtf8(f.readLine()).trimmed();
            if (line.startsWith("PRETTY_NAME=")) {
                QString val = line.mid(12);
                if (val.startsWith('"') && val.endsWith('"'))
                    val = val.mid(1, val.length() - 2);
                return val;
            }
        }
        return "Unknown";
    }();
#else
    buildInfo["distroName"] = "Windows";
#endif
    buildInfo["copyright"] = QString(buildInfo["author"].toString() + " " + (__DATE__ + 7));

    QQmlApplicationEngine engine;

    // Register backend
    qmlRegisterType<GuineaMpegBackend>("GuineaMpeg", 1, 0, "GuineaMpegBackend");
    qmlRegisterType<MpvItem>("GuineaMpeg", 1, 0, "MpvItem");
    auto backend = new GuineaMpegBackend(&app);
    engine.rootContext()->setContextProperty("backend", backend);
    engine.rootContext()->setContextProperty("ffmpegAvailable", QVariant(backend->ffmpegAvailable()));
    engine.rootContext()->setContextProperty("ffmpegVersion", QVariant(backend->getFfmpegVersion()));
    engine.rootContext()->setContextProperty("buildInfo", QVariant(buildInfo));

    QString initialFilePath;
    auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const auto& a = args[i];
        if (a == "@@" || a.startsWith("@@") || a.startsWith('-'))
            continue;
        QString path = QUrl(a).toLocalFile();
        if (path.isEmpty())
            path = a;
        initialFilePath = path;
        break;
    }
    engine.rootContext()->setContextProperty("initialFilePath", QVariant(initialFilePath));

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
