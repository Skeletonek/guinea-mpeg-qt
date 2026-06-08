#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QVariantMap>

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
    Q_INVOKABLE QString loadProfile(const QString& name);
    Q_INVOKABLE bool saveProfile(const QString& name, const QString& json);
    Q_INVOKABLE bool deleteProfile(const QString& name);
    Q_INVOKABLE bool restoreDefaultProfiles();

    Q_INVOKABLE QVariantMap getVideoInfo(const QString& rawPath);
    Q_INVOKABLE bool ffmpegAvailable();
    Q_INVOKABLE QString getFfmpegVersion();
    Q_INVOKABLE QString generatePreview(const QString& rawPath, qint64 timeMs);
    Q_INVOKABLE QString generateCommandPreview(const QString& json);
    Q_INVOKABLE QString startTranscode(const QString& rawInput, const QString& rawOutput,
                                        double startTime, double endTime,
                                        const QString& profileJson);
    Q_INVOKABLE void cancelTranscode();

signals:
    void transcodeOutputUpdated();
    void transcodingChanged();
    void transcodeFinished(bool success);

private:
    void connectOutputCapture();

    QString m_transcodeOutput;
    bool m_transcoding = false;
    QProcess* m_currentTranscode = nullptr;
};
