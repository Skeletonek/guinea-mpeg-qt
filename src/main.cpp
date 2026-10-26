#include <QApplication>
#include <QDebug>
#include <QLocale>
#include <QPalette>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QStyleHints>
#include <QTranslator>

#include "backend.h"
#include "guinea_mpeg_core.h"
#include "mpvitem.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSysInfo>
#include <QUrl>
#include <clocale>

#ifdef Q_OS_WIN
#include <cstdio>
#include <iostream>
#include <windows.h>
#include <winreg.h>
#endif

// GUI apps don't inherit a console, so attach to the parent's (no-op when
// double-clicked) and redirect the CRT streams to it.
static void attachParentConsole() {
#ifdef Q_OS_WIN
    if (!AttachConsole(ATTACH_PARENT_PROCESS))
        return;
    FILE* fp = nullptr;
    freopen_s(&fp, "CONOUT$", "w", stdout);
    freopen_s(&fp, "CONOUT$", "w", stderr);
    freopen_s(&fp, "CONIN$", "r", stdin);
    std::ios::sync_with_stdio(true);
#endif
}

static QJsonObject readAppOptions() {
    const char* json = guinea_mpeg_get_options();
    if (!json)
        return {};
    QJsonObject opts = QJsonDocument::fromJson(QByteArray(json)).object();
    guinea_mpeg_free_string(json);
    return opts;
}

static QStringList availableQmlStyles() {
    static const QStringList candidates = {QStringLiteral("Fusion"),   QStringLiteral("Universal"),
                                           QStringLiteral("Material"), QStringLiteral("Windows"),
                                           QStringLiteral("Imagine"),  QStringLiteral("FluentWinUI3")};

    QStringList styles;
    const QQmlEngine probe;
    const QStringList importPaths = probe.importPathList();
    for (const QString& style : candidates) {
        for (const QString& p : importPaths) {
            if (QFileInfo::exists(p + QLatin1String("/QtQuick/Controls/") + style + QLatin1String("/qmldir"))) {
                styles << style;
                break;
            }
        }
    }
#ifdef Q_OS_LINUX
    // Breeze is shipped outside QtQuick/Controls (org.kde.desktop).
    for (const QString& p : importPaths) {
        if (QFileInfo::exists(p + QLatin1String("/org/kde/desktop/qmldir"))) {
            styles << QStringLiteral("org.kde.desktop");
            break;
        }
    }
#endif
    return styles;
}

static QPalette makeDarkPalette() {
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
}

static QPalette makeLightPalette() {
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
}

static Qt::ColorScheme detectSystemColorScheme() {
    Qt::ColorScheme scheme = QApplication::styleHints()->colorScheme();
#ifdef Q_OS_WIN
    if (scheme == Qt::ColorScheme::Unknown) {
        // Fallback: read Windows "apps use light theme" registry value.
        DWORD value = 1;
        DWORD size = sizeof(value);
        if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                         L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &size) == ERROR_SUCCESS)
            scheme = value ? Qt::ColorScheme::Light : Qt::ColorScheme::Dark;
    }
#endif
    if (scheme == Qt::ColorScheme::Unknown)
        scheme = Qt::ColorScheme::Light;
    return scheme;
}

// MangoHud crashes this app at startup when MANGOHUD is set; it is evaluated
// per Vulkan instance, so drop it before any GL/Vulkan context exists.
static void dropMangoHudFromEnvironment() {
#ifdef Q_OS_LINUX
    const QString mh = QString::fromLocal8Bit(qgetenv("MANGOHUD"));
    if (mh.trimmed().isEmpty() || mh.trimmed() == QStringLiteral("0"))
        return;
    qunsetenv("MANGOHUD");
#endif
}

static QString osReleasePretty(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    while (!f.atEnd()) {
        QString line = QString::fromUtf8(f.readLine()).trimmed();
        if (!line.startsWith("PRETTY_NAME="))
            continue;
        QString val = line.mid(12).trimmed();
        if (val.size() >= 2 && val.startsWith('"') && val.endsWith('"'))
            val = val.mid(1, val.size() - 2);
        return val;
    }
    return {};
}

static QString getHostOsName() {
    const bool isFlatpak = QStringLiteral(PACKAGE_TARGET) == QStringLiteral("flatpak");
    QString name;
    if (isFlatpak)
        name = osReleasePretty(QStringLiteral("/run/host/etc/os-release"));
    if (name.isEmpty())
        name = osReleasePretty(QStringLiteral("/etc/os-release"));
    if (!name.isEmpty())
        return name;
    return QSysInfo::prettyProductName();
}

static QVariantMap buildThemeMap(const QPalette& pal, bool darkTheme) {
    auto hex = [](const QColor& c) { return c.name(QColor::HexArgb); };
    QColor bgCol = pal.color(QPalette::Window);
    QColor txtCol = pal.color(QPalette::WindowText);
    QColor btnCol = pal.color(QPalette::Button);
    auto blend = [](const QColor& a, const QColor& b, double t) {
        return QColor(int(a.red() * (1 - t) + b.red() * t), int(a.green() * (1 - t) + b.green() * t),
                      int(a.blue() * (1 - t) + b.blue() * t), int(a.alpha() * (1 - t) + b.alpha() * t));
    };
    QVariantMap theme;
    theme["bg"] = hex(bgCol);
    theme["surface"] = hex(pal.color(QPalette::Base));
    theme["widget"] = hex(btnCol);
    theme["widgetBorder"] = hex(pal.color(QPalette::Mid));
    theme["text"] = hex(txtCol);
    theme["textSecondary"] = hex(blend(txtCol, bgCol, 0.4));
    theme["textMuted"] = hex(blend(txtCol, bgCol, 0.65));
    theme["textHeader"] = hex(txtCol);
    theme["textDim"] = hex(blend(txtCol, bgCol, 0.8));
    theme["accent"] = hex(pal.color(QPalette::Highlight));
    theme["accentEnd"] = hex(pal.color(QPalette::Highlight));
    theme["black"] = "#000000";
    theme["warning"] = "#e6a23c";
    QColor overlayCol = txtCol;
    overlayCol.setAlpha(darkTheme ? 128 : 64);
    theme["overlay"] = hex(overlayCol);
    return theme;
}

static QVariantMap buildBuildInfoMap(const QString& hostOs) {
    QVariantMap buildInfo;
    buildInfo["author"] = "Skeletonek";
    buildInfo["license"] = "BSD 3-Clause";
#ifdef QT_NO_DEBUG
    buildInfo["debugBuild"] = false;
    buildInfo["version"] = PROJECT_VERSION_FULL;
#else
    buildInfo["debugBuild"] = true;
    buildInfo["version"] = QStringLiteral(PROJECT_VERSION_FULL) + QStringLiteral(" (development build)");
#endif
    buildInfo["buildDate"] = __DATE__ " " __TIME__;
    buildInfo["packageTarget"] = PACKAGE_TARGET;
    buildInfo["distroName"] = hostOs;
    buildInfo["qtVersion"] = qVersion();
#if defined(__aarch64__) || defined(_M_ARM64)
    buildInfo["cpuArch"] = QStringLiteral("aarch64");
#elif defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64)
    buildInfo["cpuArch"] = QStringLiteral("x86_64");
#else
    buildInfo["cpuArch"] = QSysInfo::currentCpuArchitecture();
#endif
    buildInfo["copyright"] =
        buildInfo["author"].toString() + QStringLiteral(" ") + QString::fromLatin1(__DATE__).right(4);
    return buildInfo;
}

static QString parseInitialFilePath(const QStringList& args) {
    for (int i = 1; i < args.size(); ++i) {
        const QString& a = args.at(i);
        if (a.startsWith("@@") || a.startsWith('-'))
            continue;
        QString path = QUrl(a).toLocalFile();
        if (path.isEmpty())
            path = a;
#ifdef Q_OS_WIN
        if (path.size() >= 3 && path[0] == '/' && path[2] == ':')
            path = path.mid(1);
#endif
        return QDir::cleanPath(path);
    }
    return {};
}

int main(int argc, char* argv[]) {
    dropMangoHudFromEnvironment();
    attachParentConsole();
    QApplication app(argc, argv);
#ifdef Q_OS_LINUX
    app.setDesktopFileName("guinea-mpeg");
    app.setWindowIcon(QIcon::fromTheme("guinea-mpeg"));
#elif defined(Q_OS_WIN)
    // Qt never reads the .rc-embedded exe icon for the titlebar; load it explicitly.
    app.setWindowIcon(QIcon(QStringLiteral(":/media/logo/app.ico")));
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
    QString colorSchemeOption = appOptions.value("color_scheme").toString(QStringLiteral("system"));

#ifdef Q_OS_WIN
    // Find bundled ffmpeg/ffprobe
    QByteArray appDir = QCoreApplication::applicationDirPath().toUtf8();
    SetEnvironmentVariableA("PATH", (appDir + ";" + qgetenv("PATH")).constData());
#endif

    QStringList availableStyles = availableQmlStyles();

    if (themeOption != QLatin1String("system") && !availableStyles.contains(themeOption))
        themeOption = QStringLiteral("system");
    if (themeOption != QLatin1String("system"))
        QQuickStyle::setStyle(themeOption);
#ifdef Q_OS_WIN
    else
        QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));
#endif

    // Release builds lock Material/Universal/Imagine to light (dark text on dark
    // controls otherwise); Debug allows the full combination, so say so.
    static const QStringList schemeLockedStyles = {QStringLiteral("Material"), QStringLiteral("Universal"),
                                                   QStringLiteral("Imagine")};
    QStringList colorSchemeLockedStyles;
#ifdef QT_NO_DEBUG
    colorSchemeLockedStyles = schemeLockedStyles;
#endif
    if (schemeLockedStyles.contains(themeOption)) {
#ifdef QT_NO_DEBUG
        colorSchemeOption = QStringLiteral("light");
#else
        qInfo().nospace() << "Debug build: " << themeOption
                          << " is not locked to the light scheme (release builds force it).";
#endif
    }

    // An explicit dark/light choice forces our palette + QStyleHints scheme.
    // "system" follows the OS: Linux platform themes already provide the
    // palette, Windows mixes light/dark and needs the forced one.
    Qt::ColorScheme effectiveScheme = Qt::ColorScheme::Light;
    const bool explicitScheme =
        colorSchemeOption == QLatin1String("dark") || colorSchemeOption == QLatin1String("light");
    if (colorSchemeOption == QLatin1String("dark"))
        effectiveScheme = Qt::ColorScheme::Dark;
    else if (colorSchemeOption == QLatin1String("light"))
        effectiveScheme = Qt::ColorScheme::Light;
    else
        effectiveScheme = detectSystemColorScheme();

    const bool darkTheme = effectiveScheme == Qt::ColorScheme::Dark;
    if (explicitScheme
#ifdef Q_OS_WIN
        || colorSchemeOption == QLatin1String("system")
#endif
    ) {
        app.setPalette(darkTheme ? makeDarkPalette() : makeLightPalette());
        QApplication::styleHints()->setColorScheme(effectiveScheme);
    }

    QVariantMap theme = buildThemeMap(app.palette(), darkTheme);

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QVariantMap buildInfo = buildBuildInfoMap(getHostOsName());

    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/qml");

    qmlRegisterType<GuineaMpegBackendExt>("GuineaMpeg", 1, 0, "GuineaMpegBackendExt");
    qmlRegisterType<MpvItem>("GuineaMpeg", 1, 0, "MpvItem");
    auto backend = new GuineaMpegBackendExt(&app);
    engine.rootContext()->setContextProperty("backend", backend);
    engine.rootContext()->setContextProperty("ffmpegAvailable", backend->ffmpegAvailable());
    engine.rootContext()->setContextProperty("ffmpegVersion", backend->getFfmpegVersion());
    engine.rootContext()->setContextProperty("mpvAvailable", guinea_mpeg_mpv_available());
    engine.rootContext()->setContextProperty("mpvVersion", backend->getMpvVersion());
    engine.rootContext()->setContextProperty("buildInfo", buildInfo);
    engine.rootContext()->setContextProperty("theme", theme);
    engine.rootContext()->setContextProperty("availableStyles", availableStyles);
    engine.rootContext()->setContextProperty("currentStyle", QQuickStyle::name());
    engine.rootContext()->setContextProperty("colorSchemeLockedStyles", colorSchemeLockedStyles);

    QString initialFilePath = parseInitialFilePath(app.arguments());
    engine.rootContext()->setContextProperty("initialFilePath", QVariant(initialFilePath));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    return app.exec();
}
