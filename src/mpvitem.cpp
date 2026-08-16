#include "mpvitem.h"
#include "guinea_mpeg_core.h"
#include <mpv/client.h>
#include <mpv/render.h>
#include <mpv/render_gl.h>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QQuickWindow>
#include <QDebug>

#include <algorithm>

MpvRenderer::MpvRenderer(MpvItem* item)
    : m_item(item)
{
    initializeOpenGLFunctions();

    mpv_opengl_init_params gl_init{ .get_proc_address = getProcAddr, .get_proc_address_ctx = nullptr };
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(MPV_RENDER_API_TYPE_OPENGL) },
        { MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init },
        { MPV_RENDER_PARAM_INVALID, nullptr }
    };

    if (mpv_render_context_create(&m_renderCtx, item->getMpv(), params) < 0) {
        qWarning() << "mpv: failed to create render context";
        return;
    }
    mpv_render_context_set_update_callback(m_renderCtx, MpvItem::onUpdate, item);

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

    QOpenGLFramebufferObject* fbo = framebufferObject();
    const QSize sz = fbo->size();
    glViewport(0, 0, sz.width(), sz.height());
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    mpv_opengl_fbo mpfbo{
        .fbo = static_cast<int>(fbo->handle()),
        .w = sz.width(),
        .h = sz.height(),
        .internal_format = 0
    };
    int flip = 1;
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo },
        { MPV_RENDER_PARAM_FLIP_Y, &flip },
        { MPV_RENDER_PARAM_INVALID, nullptr }
    };
    if (mpv_render_context_render(m_renderCtx, params) < 0)
        qWarning() << "mpv: render failed";
}

void MpvRenderer::synchronize(QQuickFramebufferObject*)
{
}

void* MpvRenderer::getProcAddr(void*, const char* name)
{
    return reinterpret_cast<void*>(QOpenGLContext::currentContext()->getProcAddress(name));
}

void MpvItem::onUpdate(void* ctx)
{
    auto* item = static_cast<MpvItem*>(ctx);
    QMetaObject::invokeMethod(item, "update", Qt::QueuedConnection);
}

MpvItem::MpvItem()
{
    setMirrorVertically(true);

    m_backend = guinea_mpeg_mpv_create();
    if (!m_backend) {
        qWarning() << "mpv: failed to create backend";
        return;
    }

    m_mpv = static_cast<mpv_handle*>(guinea_mpeg_mpv_raw_handle(m_backend));
    m_volume = guinea_mpeg_mpv_volume(m_backend);

    mpv_set_wakeup_callback(m_mpv, wakeup, this);
    connect(this, &MpvItem::onMpvEvents, this, &MpvItem::handleMpvEvents, Qt::QueuedConnection);

    // mpv's wakeup callback can be unreliable (lost wakeups) or fire
    // reentrantly on some platforms (notably Windows), so also poll events
    // on a fixed interval. The drain is cheap when the queue is empty and
    // guarantees position/duration updates even if the wakeup path fails.
    m_eventTimer = new QTimer(this);
    m_eventTimer->setInterval(50);
    connect(m_eventTimer, &QTimer::timeout, this, &MpvItem::handleMpvEvents);
    m_eventTimer->start();
}

MpvItem::~MpvItem()
{
    if (m_backend)
        guinea_mpeg_mpv_destroy(m_backend);
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

    if (m_backend && m_renderReady)
        loadPendingSource();

    emit sourceChanged();
}

void MpvItem::loadPendingSource()
{
    if (!m_backend || m_pendingSource.isEmpty()) return;

    QUrl src = m_pendingSource;
    m_pendingSource = QUrl();

    QString path = src.toLocalFile();
    if (path.isEmpty())
        path = src.toString();

    QByteArray pathData = path.toUtf8();
    guinea_mpeg_mpv_load_file(m_backend, pathData.constData());
    // load_file autoplays
    m_playing = true;
    emit playingChanged();
}

void MpvItem::setPosition(int pos)
{
    if (!m_backend) return;
    guinea_mpeg_mpv_seek(m_backend, pos);
}

void MpvItem::play()
{
    if (!m_backend) return;
    if (m_duration > 0 && m_position >= m_duration - 500) {
        guinea_mpeg_mpv_seek(m_backend, 0);
        m_position = 0;
        emit positionChanged();
    }
    guinea_mpeg_mpv_play(m_backend);
    m_playing = true;
    emit playingChanged();
}

void MpvItem::pause()
{
    if (!m_backend) return;
    guinea_mpeg_mpv_pause(m_backend);
    m_playing = false;
    emit playingChanged();
}

void MpvItem::stop()
{
    if (!m_backend) return;
    guinea_mpeg_mpv_stop(m_backend);
    m_playing = false;
    m_position = 0;
    emit playingChanged();
    emit positionChanged();
}

void MpvItem::setVolume(qreal vol)
{
    m_volume = vol;
    if (m_backend) {
        const int v = std::clamp(static_cast<int>(vol), 0, 100);
        guinea_mpeg_mpv_set_volume(m_backend, v);
    }
    emit volumeChanged();
}

QQuickFramebufferObject::Renderer* MpvItem::createRenderer() const
{
    return new MpvRenderer(const_cast<MpvItem*>(this));
}

void MpvItem::handleMpvEvents()
{
    if (!m_backend) return;

    int changed = guinea_mpeg_mpv_process_events(m_backend);

    if (changed & 1) {
        m_position = guinea_mpeg_mpv_position(m_backend);
        emit positionChanged();
    }
    if (changed & 2) {
        m_duration = guinea_mpeg_mpv_duration(m_backend);
        emit durationChanged();
    }
    if (changed & 4) {
        m_playing = guinea_mpeg_mpv_is_playing(m_backend);
        emit playingChanged();
    }
}

void MpvItem::wakeup(void* ctx)
{
    auto* item = static_cast<MpvItem*>(ctx);
    emit item->onMpvEvents();
}
