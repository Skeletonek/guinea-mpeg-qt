#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QPalette>
#include <QStyleHints>
#include <QTranslator>
#include <QLocale>

#include <clocale>
#include "mpvitem.h"
#include "backend.h"
#include "guinea_mpeg_core.h"
#include <QDir>
#include <QIcon>
#include <QUrl>
#include <QSysInfo>
#include <QJsonDocument>
#include <QJsonObject>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

static QJsonObject readAppOptions()
{
    const char* json = guinea_mpeg_get_options();
    if (!json) return {};
    QJsonObject opts = QJsonDocument::fromJson(QByteArray(json)).object();
    guinea_mpeg_free_string(json);
    return opts;
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
#ifdef Q_OS_LINUX
    app.setDesktopFileName("guinea-mpeg");
    app.setWindowIcon(QIcon::fromTheme("guinea-mpeg"));
#endif
    std::setlocale(LC_NUMERIC, "C");

    QJsonObject appOptions = readAppOptions();

    QString language = appOptions.value("language").toString(QStringLiteral("system"));
    QTranslator translator;
    if (language == "system" || language.isEmpty()) {
        if (translator.load(QLocale(), "guinea-mpeg", "_", ":/i18n/qml"))
            app.installTranslator(&translator);
    } else if (language != "en") {
        if (translator.load(QLocale(language), "guinea-mpeg", "_", ":/i18n/qml"))
            app.installTranslator(&translator);
    }

    QString themeOption = appOptions.value("theme").toString(QStringLiteral("system"));
    bool forcedTheme = (themeOption == "dark" || themeOption == "light");

    auto makeDarkPalette = []() {
        QPalette p;
        p.setColor(QPalette::Window, QColor(53, 53, 53));
        p.setColor(QPalette::WindowText, QColor(220, 220, 220));
        p.setColor(QPalette::Base, QColor(42, 42, 42));
        p.setColor(QPalette::AlternateBase, QColor(66, 66, 66));
        p.setColor(QPalette::ToolTipBase, QColor(53, 53, 53));
        p.setColor(QPalette::ToolTipText, QColor(220, 220, 220));
        p.setColor(QPalette::Text, QColor(220, 220, 220));
        p.setColor(QPalette::Button, QColor(53, 53, 53));
        p.setColor(QPalette::ButtonText, QColor(220, 220, 220));
        p.setColor(QPalette::BrightText, QColor(255, 0, 0));
        p.setColor(QPalette::Link, QColor(42, 130, 218));
        p.setColor(QPalette::Highlight, QColor(42, 130, 218));
        p.setColor(QPalette::HighlightedText, QColor(220, 220, 220));
        p.setColor(QPalette::Mid, QColor(80, 80, 80));
        return p;
    };
    auto makeLightPalette = []() {
        QPalette p;
        p.setColor(QPalette::Window, QColor(240, 240, 240));
        p.setColor(QPalette::WindowText, QColor(0, 0, 0));
        p.setColor(QPalette::Base, QColor(255, 255, 255));
        p.setColor(QPalette::AlternateBase, QColor(245, 245, 245));
        p.setColor(QPalette::ToolTipBase, QColor(255, 255, 220));
        p.setColor(QPalette::ToolTipText, QColor(0, 0, 0));
        p.setColor(QPalette::Text, QColor(0, 0, 0));
        p.setColor(QPalette::Button, QColor(225, 225, 225));
        p.setColor(QPalette::ButtonText, QColor(0, 0, 0));
        p.setColor(QPalette::BrightText, QColor(255, 0, 0));
        p.setColor(QPalette::Link, QColor(0, 120, 215));
        p.setColor(QPalette::Highlight, QColor(0, 120, 215));
        p.setColor(QPalette::HighlightedText, QColor(255, 255, 255));
        p.setColor(QPalette::Mid, QColor(190, 190, 190));
        return p;
    };

    bool useFusion = forcedTheme;
#ifdef Q_OS_WIN
    // Find bundled ffmpeg/ffprobe
    QByteArray appDir = QCoreApplication::applicationDirPath().toUtf8();
    SetEnvironmentVariableA("PATH", (appDir + ";" + qgetenv("PATH")).constData());
    // Windows: always Fusion (native QML style forbids background overrides)
    useFusion = true;
#else
    if (QStringLiteral(PACKAGE_TARGET) == "appimage")
        useFusion = true;
#endif

    bool darkTheme = false;

    if (useFusion) {
        QQuickStyle::setStyle("Fusion");
        if (forcedTheme) {
            darkTheme = (themeOption == "dark");
            app.setPalette(darkTheme ? makeDarkPalette() : makeLightPalette());
        } else {
#ifdef Q_OS_WIN
            // Windows: force dark palette (Fusion in light mode looks wrong)
            app.setPalette(makeDarkPalette());
            darkTheme = true;
#else
            // AppImage: respect system theme
            darkTheme = QApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
            if (darkTheme)
                app.setPalette(makeDarkPalette());
#endif
        }
    } else {
        // Native Linux: respect system theme
        darkTheme = QApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    }

    QVariantMap theme;
    {
        QPalette pal = app.palette();

        auto hex = [](const QColor &c) { return c.name(QColor::HexArgb); };

        QColor bgCol = pal.color(QPalette::Window);
        QColor txtCol = pal.color(QPalette::WindowText);
        QColor btnCol = pal.color(QPalette::Button);

        auto blend = [](const QColor &a, const QColor &b, double t) {
            return QColor(
                int(a.red() * (1 - t) + b.red() * t),
                int(a.green() * (1 - t) + b.green() * t),
                int(a.blue() * (1 - t) + b.blue() * t),
                int(a.alpha() * (1 - t) + b.alpha() * t)
            );
        };

        theme["bg"]            = hex(bgCol);
        theme["surface"]       = hex(pal.color(QPalette::Base));
        theme["widget"]        = hex(btnCol);
        theme["widgetBorder"]  = hex(pal.color(QPalette::Mid));
        theme["text"]          = hex(txtCol);
        theme["textSecondary"] = hex(blend(txtCol, bgCol, 0.4));
        theme["textMuted"]     = hex(blend(txtCol, bgCol, 0.65));
        theme["textHeader"]    = hex(txtCol);
        theme["textDim"]       = hex(blend(txtCol, bgCol, 0.8));
        theme["accent"]        = hex(pal.color(QPalette::Highlight));
        theme["accentEnd"]     = hex(pal.color(QPalette::Highlight));
        theme["black"]         = "#000000";

        QColor overlayCol = txtCol;
        overlayCol.setAlpha(darkTheme ? 128 : 64);
        theme["overlay"] = hex(overlayCol);
    }

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QVariantMap buildInfo;
    buildInfo["author"] = "Skeletonek";
    buildInfo["license"] = "BSD 3-Clause";
    buildInfo["version"] = PROJECT_VERSION_FULL;
    buildInfo["buildDate"] = __DATE__ " " __TIME__;
    buildInfo["packageTarget"] = PACKAGE_TARGET;
    buildInfo["distroName"] = QSysInfo::prettyProductName();
    buildInfo["qtVersion"] = qVersion();
    buildInfo["copyright"] = QString(buildInfo["author"].toString() + " " + QString(__DATE__).right(4));

    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/qml");

    qmlRegisterType<GuineaMpegBackendExt>("GuineaMpeg", 1, 0, "GuineaMpegBackendExt");
    qmlRegisterType<MpvItem>("GuineaMpeg", 1, 0, "MpvItem");
    auto backend = new GuineaMpegBackendExt(&app);
    engine.rootContext()->setContextProperty("backend", backend);
    engine.rootContext()->setContextProperty("ffmpegAvailable", QVariant(backend->ffmpegAvailable()));
    engine.rootContext()->setContextProperty("ffmpegVersion", QVariant(backend->getFfmpegVersion()));
    engine.rootContext()->setContextProperty("mpvAvailable", QVariant(guinea_mpeg_mpv_available()));
    engine.rootContext()->setContextProperty("mpvVersion", QVariant(backend->getMpvVersion()));
    engine.rootContext()->setContextProperty("buildInfo", QVariant(buildInfo));
    engine.rootContext()->setContextProperty("theme", QVariant(theme));

    QString initialFilePath;
    auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const auto& a = args[i];
        if (a.startsWith("@@") || a.startsWith('-'))
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
        []() {
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
    );
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    return app.exec();
}
