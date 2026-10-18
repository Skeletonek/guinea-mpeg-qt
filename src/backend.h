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
    Q_PROPERTY(QString transcodeError READ transcodeError NOTIFY transcodeErrorChanged)
    Q_PROPERTY(bool transcoding READ transcoding WRITE setTranscoding NOTIFY transcodingChanged)
    Q_PROPERTY(bool previewGenerating READ previewGenerating WRITE setPreviewGenerating NOTIFY previewGeneratingChanged)
    Q_PROPERTY(QString lastPreviewPath READ lastPreviewPath NOTIFY lastPreviewPathChanged)
    Q_PROPERTY(qint64 lastPreviewSize READ lastPreviewSize NOTIFY lastPreviewSizeChanged)
    Q_PROPERTY(qint64 lastPreviewDurationMs READ lastPreviewDurationMs NOTIFY lastPreviewDurationMsChanged)
    Q_PROPERTY(QString previewOutput READ previewOutput NOTIFY previewOutputUpdated)
    Q_PROPERTY(QString lastPreviewError READ lastPreviewError NOTIFY lastPreviewErrorChanged)
  public:
    explicit GuineaMpegBackendExt(QObject* parent = nullptr);
    ~GuineaMpegBackendExt();

    QString transcodeOutput() const {
        return m_transcodeOutput;
    }
    void setTranscodeOutput(const QString& v);

    QString transcodeError() const {
        return m_transcodeError;
    }
    void setTranscodeError(const QString& v);

    bool transcoding() const {
        return m_transcoding;
    }
    void setTranscoding(bool v);

    bool previewGenerating() const {
        return m_previewGenerating;
    }
    void setPreviewGenerating(bool v);

    QString lastPreviewPath() const {
        return m_lastPreviewPath;
    }
    qint64 lastPreviewSize() const {
        return m_lastPreviewSize;
    }
    qint64 lastPreviewDurationMs() const {
        return m_lastPreviewDurationMs;
    }
    QString lastPreviewError() const {
        return m_lastPreviewError;
    }
    QString previewOutput() const {
        return m_previewStderr;
    }
    Q_INVOKABLE void resetPreview();

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

    Q_INVOKABLE bool fileExists(const QString& rawPath);
    Q_INVOKABLE void systemBeep();

    Q_INVOKABLE QVariantMap getVideoInfo(const QString& rawPath);
    Q_INVOKABLE bool ffmpegAvailable();
    Q_INVOKABLE QString getFfmpegVersion();
    Q_INVOKABLE QString getMpvVersion();
    Q_INVOKABLE QString generatePreview(const QString& rawPath, qint64 timeMs);
    Q_INVOKABLE QString generateCommandPreview(const QString& json);
    Q_INVOKABLE QString availableEncoders();
    Q_INVOKABLE QString encoderCapabilities(const QString& encoderName);
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE QString startTranscode(const QString& rawInput, const QString& rawOutput, double startTime,
                                       double endTime, const QString& profileJson);
    Q_INVOKABLE void cancelTranscode();
    Q_INVOKABLE void clearTranscodeOutput();
    Q_INVOKABLE QString startPreview(const QString& rawInput, const QString& profileJson, double startTimeMs,
                                     double durationMs, const QString& extension);
    Q_INVOKABLE void cancelPreview();

  signals:
    void transcodeOutputUpdated();
    void transcodeErrorChanged();
    void transcodingChanged();
    void transcodeFinished(bool success);
    void previewGeneratingChanged();
    void previewGenerated(const QString& path);
    void previewFailed();
    void lastPreviewPathChanged();
    void lastPreviewSizeChanged();
    void lastPreviewDurationMsChanged();
    void previewOutputUpdated();
    void lastPreviewErrorChanged();

  private:
    void connectOutputCapture(QProcess* proc);
    void appendTranscodeOutput(const QString& chunk);
    void sendNotification(const QString& title, const QString& body);

    QString m_transcodeOutput;
    QString m_transcodeError;
    bool m_transcoding = false;
    bool m_previewGenerating = false;
    QString m_lastPreviewPath;
    qint64 m_lastPreviewSize = 0;
    qint64 m_lastPreviewDurationMs = 5000;
    QString m_lastPreviewError;
    QString m_previewStderr;
    QString extractTranscodeError(const QString& output) const;
    std::unique_ptr<QProcess> m_currentTranscode;
    std::unique_ptr<QProcess> m_currentPreview;
#ifdef Q_OS_WIN
    QSystemTrayIcon* m_trayIcon = nullptr;
#endif
};
