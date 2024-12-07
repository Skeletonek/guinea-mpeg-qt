#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QProcess>
#include <QQuickStyle>
#include <iostream>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQuickStyle::setStyle("org.kde.desktop");

    QQmlApplicationEngine engine;
    const QUrl url(u"qrc:/guinea_mpeg/Main.qml"_qs);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    QProcess process;
    process.start("ffmpeg", QStringList() << "-help");
    process.waitForFinished();
    QByteArray sout = process.readAllStandardOutput();
    std::cout << sout.toStdString();

    QObject *root = engine.rootObjects()[0];
    QObject *col = root->findChild<QObject*>("col");
    QObject *sv = root->findChild<QObject*>("sv");
    QObject *textOutput = sv->findChild<QObject*>("textOutput");
    if (true) {
        std::cout << "Found textOutput" << std::endl;
        textOutput->setProperty("text", sout);
    }

    return app.exec();
}
