#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QVariantMap>

#include <memory>
#ifdef Q_OS_WIN
#include <QSystemTrayIcon>
#endif

class GuineaMpegBackendExt : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString transcodeOutput READ transcodeOutput WRITE setTranscodeOutput NOTIFY transcodeOutputUpdated)
    Q_PROPERTY(bool transcoding READ transcoding WRITE setTranscoding NOTIFY transcodingChanged)
public:
    explicit GuineaMpegBackendExt(QObject* parent = nullptr);
    ~GuineaMpegBackendExt();

    QString transcodeOutput() const { return m_transcodeOutput; }
    void setTranscodeOutput(const QString& v);

    bool transcoding() const { return m_transcoding; }
    void setTranscoding(bool v);

    Q_INVOKABLE QString availableProfiles();
    Q_INVOKABLE QString userProfileNames();
    Q_INVOKABLE QString defaultProfileNames();
    Q_INVOKABLE QString loadProfile(const QString& name);
    Q_INVOKABLE bool saveProfile(const QString& name, const QString& json);
    Q_INVOKABLE bool deleteProfile(const QString& name);
    Q_INVOKABLE bool restoreDefaultProfiles();

    Q_INVOKABLE bool exportProfiles(const QString& path, const QString& namesJson);
    Q_INVOKABLE QString importProfilesPreview(const QString& path);
    Q_INVOKABLE QString importProfiles(const QString& path, bool overwrite);

    Q_INVOKABLE QString getOptions();
    Q_INVOKABLE bool setOption(const QString& key, const QString& value);

    Q_INVOKABLE QVariantMap getVideoInfo(const QString& rawPath);
    Q_INVOKABLE bool ffmpegAvailable();
    Q_INVOKABLE QString getFfmpegVersion();
    Q_INVOKABLE QString getMpvVersion();
    Q_INVOKABLE QString generatePreview(const QString& rawPath, qint64 timeMs);
    Q_INVOKABLE QString generateCommandPreview(const QString& json);
    Q_INVOKABLE QString availableEncoders();
    Q_INVOKABLE QString encoderCapabilities(const QString& encoderName);
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE QString startTranscode(const QString& rawInput, const QString& rawOutput,
                                        double startTime, double endTime,
                                        const QString& profileJson);
    Q_INVOKABLE void cancelTranscode();

signals:
    void transcodeOutputUpdated();
    void transcodingChanged();
    void transcodeFinished(bool success);

private:
    void connectOutputCapture(QProcess* proc);
    void appendTranscodeOutput(const QString& chunk);
    void sendNotification(const QString& title, const QString& body);

    QString m_transcodeOutput;
    bool m_transcoding = false;
    std::unique_ptr<QProcess> m_currentTranscode;
#ifdef Q_OS_WIN
    QSystemTrayIcon* m_trayIcon = nullptr;
#endif
};
