#include "mpvitem.h"
#include <mpv/client.h>
#include <mpv/render.h>
#include <mpv/render_gl.h>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QQuickWindow>
#include <QDebug>

// ---- MpvRenderer (render thread) ----

MpvRenderer::MpvRenderer(MpvItem* item)
    : m_item(item)
{
    initializeOpenGLFunctions();

    mpv_opengl_init_params gl_init{ getProcAddr, nullptr };
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(MPV_RENDER_API_TYPE_OPENGL) },
        { MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init },
        { MPV_RENDER_PARAM_INVALID, nullptr }
    };

    int r = mpv_render_context_create(&m_renderCtx, item->getMpv(), params);
    qDebug() << "mpv: render context created:" << (r >= 0 ? "ok" : mpv_error_string(r));
    if (r < 0) {
        qWarning() << "mpv: failed to create render context";
        return;
    }
    mpv_render_context_set_update_callback(m_renderCtx, MpvItem::onUpdate, item);

    // Mark render context as ready and trigger deferred load
    item->m_renderReady = true;
    QMetaObject::invokeMethod(item, "loadPendingSource", Qt::QueuedConnection);
}

MpvRenderer::~MpvRenderer()
{
    if (m_renderCtx)
        mpv_render_context_free(m_renderCtx);
}

QOpenGLFramebufferObject* MpvRenderer::createFramebufferObject(const QSize& size)
{
    return new QOpenGLFramebufferObject(size);
}

void MpvRenderer::render()
{
    if (!m_renderCtx)
        return;

    QSize sz = framebufferObject()->size();
    glViewport(0, 0, sz.width(), sz.height());
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    mpv_opengl_fbo mpfbo{
        static_cast<int>(framebufferObject()->handle()),
        sz.width(),
        sz.height(),
        0
    };
    int flip = 1;
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo },
        { MPV_RENDER_PARAM_FLIP_Y, &flip },
        { MPV_RENDER_PARAM_INVALID, nullptr }
    };
    static bool firstRender = true;
    if (firstRender) {
        firstRender = false;
        int64_t w = 0, h = 0;
        int flag = 0;
        mpv_get_property(m_item->getMpv(), "width", MPV_FORMAT_INT64, &w);
        mpv_get_property(m_item->getMpv(), "height", MPV_FORMAT_INT64, &h);
        mpv_get_property(m_item->getMpv(), "pause", MPV_FORMAT_FLAG, &flag);
        qDebug() << "mpv: first frame video=" << w << "x" << h << "pause=" << flag;
    }
    int r = mpv_render_context_render(m_renderCtx, params);
    if (r < 0)
        qWarning() << "mpv: render failed:" << mpv_error_string(r);
}

void MpvRenderer::synchronize(QQuickFramebufferObject*)
{
    // Called on GUI thread with render thread blocked.
    // Nothing to sync for now — mpv handles its own state.
}

void* MpvRenderer::getProcAddr(void*, const char* name)
{
    return (void*)QOpenGLContext::currentContext()->getProcAddress(name);
}

void MpvItem::onUpdate(void* ctx)
{
    auto* item = static_cast<MpvItem*>(ctx);
    QMetaObject::invokeMethod(item, "update", Qt::QueuedConnection);
}

// ---- MpvItem (GUI thread) ----

MpvItem::MpvItem()
{
    setMirrorVertically(true);

    m_mpv = mpv_create();
    if (!m_mpv) {
        qWarning() << "mpv: failed to create handle";
        return;
    }

    mpv_set_option_string(m_mpv, "vo", "libmpv");
    mpv_set_option_string(m_mpv, "keep-open", "yes");
    mpv_set_option_string(m_mpv, "volume", "100");
    mpv_set_option_string(m_mpv, "cache", "yes");

    if (mpv_initialize(m_mpv) < 0) {
        qWarning() << "mpv: failed to initialize";
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
        return;
    }

    mpv_set_wakeup_callback(m_mpv, wakeup, this);
    connect(this, &MpvItem::onMpvEvents, this, &MpvItem::handleMpvEvents);

    // Observe time-pos and duration for QML property updates
    mpv_observe_property(m_mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "pause", MPV_FORMAT_FLAG);

    qDebug() << "mpv: initialized successfully";
}

MpvItem::~MpvItem()
{
    if (m_mpv) {
        mpv_command_string(m_mpv, "stop");
        mpv_terminate_destroy(m_mpv);
    }
}

void MpvItem::setSource(const QUrl& source)
{
    if (m_source == source) return;
    m_source = source;
    m_pendingSource = source;

    m_position = 0;
    m_duration = 0;
    m_playing = false;
    emit positionChanged();
    emit durationChanged();
    emit playingChanged();

    if (m_mpv && m_renderReady)
        loadPendingSource();

    emit sourceChanged();
}

void MpvItem::loadPendingSource()
{
    if (!m_mpv || m_pendingSource.isEmpty()) return;

    QUrl src = m_pendingSource;
    m_pendingSource = QUrl();

    QString path = src.toLocalFile();
    if (path.isEmpty())
        path = src.toString();

    qDebug() << "mpv: loading file:" << path;
    QByteArray pathData = path.toUtf8();
    const char* cmd[] = { "loadfile", pathData.constData(), nullptr };
    int r = mpv_command(m_mpv, cmd);
    if (r < 0)
        qWarning() << "mpv: loadfile failed:" << mpv_error_string(r);
    else
        qDebug() << "mpv: loadfile succeeded";

    // Ensure playback starts
    mpv_set_property_string(m_mpv, "pause", "no");
}

void MpvItem::setPosition(int pos)
{
    if (!m_mpv) return;
    double sec = pos / 1000.0;
    QByteArray cmd = QString("seek %1 absolute").arg(sec).toUtf8();
    mpv_command_string(m_mpv, cmd.constData());
}

void MpvItem::play()
{
    if (!m_mpv) return;
    mpv_set_property_string(m_mpv, "pause", "no");
    m_playing = true;
    emit playingChanged();
}

void MpvItem::pause()
{
    if (!m_mpv) return;
    mpv_set_property_string(m_mpv, "pause", "yes");
    m_playing = false;
    emit playingChanged();
}

void MpvItem::stop()
{
    if (!m_mpv) return;
    mpv_command_string(m_mpv, "stop");
    m_playing = false;
    m_position = 0;
    emit playingChanged();
    emit positionChanged();
}

void MpvItem::setVolume(qreal vol)
{
    m_volume = vol;
    if (m_mpv) {
        int v = qBound(0, (int)(vol), 100);
        QByteArray volStr = QString::number(v).toUtf8();
        mpv_set_property_string(m_mpv, "volume", volStr.constData());
    }
    emit volumeChanged();
}

QQuickFramebufferObject::Renderer* MpvItem::createRenderer() const
{
    return new MpvRenderer(const_cast<MpvItem*>(this));
}

void MpvItem::handleMpvEvents()
{
    while (m_mpv) {
        mpv_event* event = mpv_wait_event(m_mpv, 0);
        if (event->event_id == MPV_EVENT_NONE)
            break;

        switch (event->event_id) {
        case MPV_EVENT_FILE_LOADED: {
            int64_t w = 0, h = 0;
            mpv_get_property(m_mpv, "width", MPV_FORMAT_INT64, &w);
            mpv_get_property(m_mpv, "height", MPV_FORMAT_INT64, &h);
            qDebug() << "mpv: file loaded, video=" << w << "x" << h;
            break;
        }
        case MPV_EVENT_PLAYBACK_RESTART: {
            int paused = 0;
            mpv_get_property(m_mpv, "pause", MPV_FORMAT_FLAG, &paused);
            bool was = m_playing;
            m_playing = !paused;
            if (was != m_playing)
                emit playingChanged();
            break;
        }
        case MPV_EVENT_END_FILE:
            if (m_playing) {
                m_playing = false;
                m_position = 0;
                emit playingChanged();
                emit positionChanged();
            }
            break;
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto* prop = static_cast<mpv_event_property*>(event->data);
            if (strcmp(prop->name, "time-pos") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
                int pos = static_cast<int>(*static_cast<double*>(prop->data) * 1000);
                if (pos != m_position) {
                    m_position = pos;
                    emit positionChanged();
                }
            } else if (strcmp(prop->name, "duration") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
                m_duration = static_cast<int>(*static_cast<double*>(prop->data) * 1000);
                emit durationChanged();
            } else if (strcmp(prop->name, "pause") == 0 && prop->format == MPV_FORMAT_FLAG) {
                int flag = *static_cast<int*>(prop->data);
                bool paused = flag != 0;
                if (paused != !m_playing) {
                    m_playing = !paused;
                    emit playingChanged();
                }
            }
            break;
        }
        default:
            break;
        }
    }
}

void MpvItem::wakeup(void* ctx)
{
    auto* item = static_cast<MpvItem*>(ctx);
    emit item->onMpvEvents();
}
