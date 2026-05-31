#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QPalette>
#include <QStyleHints>

#include <clocale>
#include "mpvitem.h"
#include "backend.h"
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QUrl>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
#ifdef Q_OS_LINUX
    app.setDesktopFileName("guinea-mpeg");
    app.setWindowIcon(QIcon::fromTheme("guinea-mpeg"));
#endif
    std::setlocale(LC_NUMERIC, "C");

#ifdef Q_OS_WIN
    // Ensure bundled ffmpeg/ffprobe in app directory are found by QProcess
    QByteArray appDir = QCoreApplication::applicationDirPath().toUtf8();
    SetEnvironmentVariableA("PATH", (appDir + ";" + qgetenv("PATH")).constData());

    // Fusion QML style — the native Windows style forbids background overrides
    QQuickStyle::setStyle("Fusion");
#endif

    bool darkTheme = false;
#ifdef Q_OS_WIN
    // Registry read — more reliable than QStyleHints on Windows
    HKEY hKey;
    if (RegOpenKeyExA(HKEY_CURRENT_USER,
            "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
            0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD value = 1;
        DWORD size = sizeof(value);
        if (RegGetValueA(hKey, nullptr, "AppsUseLightTheme", RRF_RT_DWORD, nullptr, &value, &size) == ERROR_SUCCESS)
            darkTheme = (value == 0);
        RegCloseKey(hKey);
    }
#else
    darkTheme = QApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
#endif

    {
        QPalette p;
        if (darkTheme) {
            p.setColor(QPalette::Window, QColor(53, 53, 53));
            p.setColor(QPalette::WindowText, Qt::white);
            p.setColor(QPalette::Base, QColor(35, 35, 35));
            p.setColor(QPalette::AlternateBase, QColor(53, 53, 53));
            p.setColor(QPalette::ToolTipBase, QColor(25, 25, 25));
            p.setColor(QPalette::ToolTipText, Qt::white);
            p.setColor(QPalette::Text, Qt::white);
            p.setColor(QPalette::Button, QColor(53, 53, 53));
            p.setColor(QPalette::ButtonText, Qt::white);
            p.setColor(QPalette::BrightText, Qt::red);
            p.setColor(QPalette::Link, QColor(42, 130, 218));
            p.setColor(QPalette::Highlight, QColor(42, 130, 218));
            p.setColor(QPalette::HighlightedText, Qt::black);
        }
        app.setPalette(p);
    }

    QVariantMap theme;
    if (darkTheme) {
        theme["bg"]            = "#1e1e1e";
        theme["surface"]       = "#2d2d2d";
        theme["widget"]        = "#333333";
        theme["widgetBorder"]  = "#555555";
        theme["text"]          = "#ffffff";
        theme["textSecondary"] = "#aaaaaa";
        theme["textMuted"]     = "#888888";
        theme["textHeader"]    = "#eeeeee";
        theme["textDim"]       = "#666666";
        theme["accent"]        = "#4a9eff";
        theme["accentEnd"]     = "#ff6b4a";
        theme["overlay"]       = "#80000000";
        theme["black"]         = "#000000";
    } else {
        theme["bg"]            = "#f0f0f0";
        theme["surface"]       = "#ffffff";
        theme["widget"]        = "#e0e0e0";
        theme["widgetBorder"]  = "#c0c0c0";
        theme["text"]          = "#000000";
        theme["textSecondary"] = "#555555";
        theme["textMuted"]     = "#999999";
        theme["textHeader"]    = "#333333";
        theme["textDim"]       = "#999999";
        theme["accent"]        = "#1a73e8";
        theme["accentEnd"]     = "#ea4335";
        theme["overlay"]       = "#40ffffff";
        theme["black"]         = "#000000";
    }

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

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
    buildInfo["copyright"] = QString(buildInfo["author"].toString() + " " + QString(__DATE__).right(4));

    QQmlApplicationEngine engine;

    qmlRegisterType<GuineaMpegBackendExt>("GuineaMpeg", 1, 0, "GuineaMpegBackendExt");
    qmlRegisterType<MpvItem>("GuineaMpeg", 1, 0, "MpvItem");
    auto backend = new GuineaMpegBackendExt(&app);
    engine.rootContext()->setContextProperty("backend", backend);
    engine.rootContext()->setContextProperty("ffmpegAvailable", QVariant(backend->ffmpegAvailable()));
    engine.rootContext()->setContextProperty("ffmpegVersion", QVariant(backend->getFfmpegVersion()));
    engine.rootContext()->setContextProperty("buildInfo", QVariant(buildInfo));
    engine.rootContext()->setContextProperty("theme", QVariant(theme));

    QString initialFilePath;
    auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const auto& a = args[i];
        if (a == "@@" || a.startsWith("@@") || a.startsWith('-'))
            continue;
        QString path = QUrl(a).toLocalFile();
        if (path.isEmpty())
            path = a;
#ifdef Q_OS_WIN
        if (path.size() >= 3 && path[0] == '/' && path[2] == ':')
            path = path.mid(1);
#endif
        initialFilePath = QDir::cleanPath(path);
        break;
    }
    engine.rootContext()->setContextProperty("initialFilePath", QVariant(initialFilePath));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    return app.exec();
}
