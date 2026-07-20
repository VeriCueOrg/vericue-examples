// veriCue GL demo - a QOpenGLWidget viewport with an orbit/pan/zoom camera.
//
// Shows that veriCue drives OpenGL viewports out of the box: the server
// synthesizes ordinary QMouse/QWheel/QTouchEvents, and the app's own camera
// code reacts exactly as it would to a real user. The camera state is exposed
// as Q_PROPERTYs (with NOTIFY signals), so tests can assert on yaw/pitch/
// distance/pan via get_properties / wait_for_property / subscribe_property
// instead of reading pixels.
//
// Controls:
//   Left drag           orbit (yaw/pitch)
//   Shift + left drag   pan
//   Middle drag         pan
//   Wheel               zoom (distance)
//   Two-finger pinch    zoom + rotate (touch)

#include <QApplication>
#include <QMainWindow>
#include <QLabel>
#include <QMatrix4x4>
#include <QMouseEvent>
#include <QOpenGLBuffer>
#include <QOpenGLFunctions>
#include <QOpenGLShaderProgram>
#include <QOpenGLWidget>
#include <QStatusBar>
#include <QTouchEvent>
#include <QWheelEvent>
#include <QtMath>

#include "vericue/server.h"

class GLViewport : public QOpenGLWidget, protected QOpenGLFunctions
{
    Q_OBJECT
    Q_PROPERTY(qreal yaw READ yaw WRITE setYaw NOTIFY cameraChanged)
    Q_PROPERTY(qreal pitch READ pitch WRITE setPitch NOTIFY cameraChanged)
    Q_PROPERTY(qreal distance READ distance WRITE setDistance NOTIFY cameraChanged)
    Q_PROPERTY(qreal panX READ panX NOTIFY cameraChanged)
    Q_PROPERTY(qreal panY READ panY NOTIFY cameraChanged)

public:
    explicit GLViewport(QWidget *parent = nullptr) : QOpenGLWidget(parent)
    {
        setAttribute(Qt::WA_AcceptTouchEvents);
        setFocusPolicy(Qt::StrongFocus);
    }

    qreal yaw() const { return m_yaw; }
    qreal pitch() const { return m_pitch; }
    qreal distance() const { return m_distance; }
    qreal panX() const { return m_panX; }
    qreal panY() const { return m_panY; }

    void setYaw(qreal v) { m_yaw = v; emitAndRepaint(); }
    void setPitch(qreal v) { m_pitch = qBound(-89.0, v, 89.0); emitAndRepaint(); }
    void setDistance(qreal v) { m_distance = qBound(0.5, v, 50.0); emitAndRepaint(); }

signals:
    void cameraChanged();

protected:
    void initializeGL() override
    {
        initializeOpenGLFunctions();
        glEnable(GL_DEPTH_TEST);

        m_program = new QOpenGLShaderProgram(this);
        m_program->addShaderFromSourceCode(QOpenGLShader::Vertex,
            "attribute vec3 pos;\n"
            "attribute vec3 col;\n"
            "uniform mat4 mvp;\n"
            "varying vec3 vCol;\n"
            "void main() { vCol = col; gl_Position = mvp * vec4(pos, 1.0); }\n");
        m_program->addShaderFromSourceCode(QOpenGLShader::Fragment,
            "varying vec3 vCol;\n"
            "void main() { gl_FragColor = vec4(vCol, 1.0); }\n");
        m_program->link();

        // Cube: 6 faces x 2 triangles, position (xyz) + face colour (rgb).
        QVector<float> v;
        auto quad = [&v](QVector3D a, QVector3D b, QVector3D c, QVector3D d, QVector3D col) {
            for (const QVector3D &p : {a, b, c, a, c, d}) {
                v << p.x() << p.y() << p.z() << col.x() << col.y() << col.z();
            }
        };
        quad({-1,-1, 1}, { 1,-1, 1}, { 1, 1, 1}, {-1, 1, 1}, {0.9f, 0.3f, 0.3f}); // front
        quad({ 1,-1,-1}, {-1,-1,-1}, {-1, 1,-1}, { 1, 1,-1}, {0.3f, 0.9f, 0.4f}); // back
        quad({ 1,-1, 1}, { 1,-1,-1}, { 1, 1,-1}, { 1, 1, 1}, {0.3f, 0.5f, 0.9f}); // right
        quad({-1,-1,-1}, {-1,-1, 1}, {-1, 1, 1}, {-1, 1,-1}, {0.9f, 0.8f, 0.3f}); // left
        quad({-1, 1, 1}, { 1, 1, 1}, { 1, 1,-1}, {-1, 1,-1}, {0.8f, 0.4f, 0.9f}); // top
        quad({-1,-1,-1}, { 1,-1,-1}, { 1,-1, 1}, {-1,-1, 1}, {0.4f, 0.9f, 0.9f}); // bottom

        m_vbo.create();
        m_vbo.bind();
        m_vbo.allocate(v.constData(), int(v.size() * sizeof(float)));
        m_vertexCount = v.size() / 6;
    }

    void paintGL() override
    {
        glClearColor(0.07f, 0.08f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        QMatrix4x4 mvp;
        mvp.perspective(45.0f, float(width()) / qMax(1, height()), 0.1f, 100.0f);
        mvp.translate(float(m_panX), float(-m_panY), float(-m_distance));
        mvp.rotate(float(m_pitch), 1, 0, 0);
        mvp.rotate(float(m_yaw), 0, 1, 0);

        m_program->bind();
        m_program->setUniformValue("mvp", mvp);
        m_vbo.bind();
        m_program->enableAttributeArray("pos");
        m_program->enableAttributeArray("col");
        m_program->setAttributeBuffer("pos", GL_FLOAT, 0, 3, 6 * sizeof(float));
        m_program->setAttributeBuffer("col", GL_FLOAT, 3 * sizeof(float), 3, 6 * sizeof(float));
        glDrawArrays(GL_TRIANGLES, 0, m_vertexCount);
    }

    void mousePressEvent(QMouseEvent *e) override
    {
        m_lastPos = e->pos();
        m_mode = (e->button() == Qt::MiddleButton
                  || (e->modifiers() & Qt::ShiftModifier)) ? Pan : Orbit;
    }

    void mouseMoveEvent(QMouseEvent *e) override
    {
        const QPoint delta = e->pos() - m_lastPos;
        m_lastPos = e->pos();
        if (m_mode == Pan) {
            m_panX += delta.x() * 0.01;
            m_panY += delta.y() * 0.01;
        } else {
            m_yaw += delta.x() * 0.5;
            m_pitch = qBound(-89.0, m_pitch + delta.y() * 0.5, 89.0);
        }
        emitAndRepaint();
    }

    void wheelEvent(QWheelEvent *e) override
    {
        const double steps = e->angleDelta().y() / 120.0;
        setDistance(m_distance * qPow(0.9, steps));
    }

    bool event(QEvent *e) override
    {
        switch (e->type()) {
        case QEvent::TouchBegin:
        case QEvent::TouchUpdate:
        case QEvent::TouchEnd: {
            auto *te = static_cast<QTouchEvent *>(e);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
            const auto points = te->points();
            auto posOf = [](const QEventPoint &p) { return p.position(); };
#else
            const auto points = te->touchPoints();
            auto posOf = [](const QTouchEvent::TouchPoint &p) { return p.pos(); };
#endif
            if (points.size() == 2) {
                const QPointF a = posOf(points[0]);
                const QPointF b = posOf(points[1]);
                const QLineF line(a, b);
                if (e->type() == QEvent::TouchBegin || m_pinchLen <= 0.0) {
                    m_pinchLen = line.length();
                    m_pinchAngle = line.angle();
                } else {
                    if (m_pinchLen > 1.0)
                        setDistance(m_distance * m_pinchLen / qMax(1.0, line.length()));
                    m_yaw += m_pinchAngle - line.angle();
                    m_pinchLen = line.length();
                    m_pinchAngle = line.angle();
                    emitAndRepaint();
                }
            }
            if (e->type() == QEvent::TouchEnd)
                m_pinchLen = 0.0;
            e->accept();
            return true;
        }
        default:
            return QOpenGLWidget::event(e);
        }
    }

private:
    void emitAndRepaint()
    {
        emit cameraChanged();
        update();
    }

    enum DragMode { Orbit, Pan };
    DragMode m_mode = Orbit;
    QPoint m_lastPos;
    qreal m_yaw = 30.0;
    qreal m_pitch = 20.0;
    qreal m_distance = 6.0;
    qreal m_panX = 0.0;
    qreal m_panY = 0.0;
    double m_pinchLen = 0.0;
    double m_pinchAngle = 0.0;

    QOpenGLShaderProgram *m_program = nullptr;
    QOpenGLBuffer m_vbo;
    int m_vertexCount = 0;
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("veriCue GL Demo"));

    quint16 port = 4246;
    const auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args[i] == QLatin1String("--port") && i + 1 < args.size())
            port = static_cast<quint16>(args[i + 1].toUShort());
    }

    QMainWindow window;
    window.setObjectName(QStringLiteral("GLWindow"));
    window.setWindowTitle(QStringLiteral("veriCue GL Demo"));
    window.resize(800, 600);

    auto *viewport = new GLViewport(&window);
    viewport->setObjectName(QStringLiteral("glViewport"));
    window.setCentralWidget(viewport);

    auto *statusLabel = new QLabel(&window);
    statusLabel->setObjectName(QStringLiteral("cameraLabel"));
    window.statusBar()->addWidget(statusLabel);
    auto updateLabel = [viewport, statusLabel]() {
        statusLabel->setText(QStringLiteral("yaw %1  pitch %2  dist %3")
                                 .arg(viewport->yaw(), 0, 'f', 1)
                                 .arg(viewport->pitch(), 0, 'f', 1)
                                 .arg(viewport->distance(), 0, 'f', 2));
    };
    QObject::connect(viewport, &GLViewport::cameraChanged, statusLabel, updateLabel);
    updateLabel();

    window.show();

    vericue::VeriCueServer server;
    if (!server.start(port)) {
        qCritical("Failed to start veriCue server on port %d", port);
        return 1;
    }
    printf("VERICUE_PORT=%d\n", server.serverPort());
    fflush(stdout);

    return app.exec();
}

#include "main.moc"
