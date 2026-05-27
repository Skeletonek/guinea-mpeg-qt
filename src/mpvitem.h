#pragma once

#include <QQuickFramebufferObject>
#include <QUrl>
#include <QOpenGLFunctions>

struct mpv_handle;
struct mpv_render_context;

class MpvRenderer;

class MpvItem : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool playing READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)

public:
    MpvItem();
    ~MpvItem();

    QUrl source() const { return m_source; }
    void setSource(const QUrl& source);

    int position() const { return m_position; }
    void setPosition(int pos);

    int duration() const { return m_duration; }
    bool isPlaying() const { return m_playing; }
    qreal volume() const { return m_volume; }

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();

    void setVolume(qreal vol);

    Renderer* createRenderer() const override;

signals:
    void sourceChanged();
    void positionChanged();
    void durationChanged();
    void playingChanged();
    void volumeChanged();
    void onMpvEvents();

private slots:
    void handleMpvEvents();

private:
    friend class MpvRenderer;
    QUrl m_source;
    int m_position = 0;
    int m_duration = 0;
    bool m_playing = false;
    qreal m_volume = 100.0;
    mpv_handle* m_mpv = nullptr;

    mpv_handle* getMpv() const { return m_mpv; }
    static void wakeup(void* ctx);
    static void onUpdate(void* ctx);
};

class MpvRenderer : public QQuickFramebufferObject::Renderer, protected QOpenGLFunctions {
public:
    MpvRenderer(MpvItem* item);
    ~MpvRenderer();

    QOpenGLFramebufferObject* createFramebufferObject(const QSize& size) override;
    void render() override;
    void synchronize(QQuickFramebufferObject* item) override;

private:
    MpvItem* m_item;
    mpv_render_context* m_renderCtx = nullptr;

    static void* getProcAddr(void* ctx, const char* name);
};
