#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>

#include "vericue/server.h"

int main(int argc, char *argv[])
{
    // Enable touch simulation from mouse events (for desktop testing)
    qputenv("QT_QUICK_MOUSE_TOUCH_EMULATION", "1");

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("veriCue Touch Demo"));

    quint16 port = 4244;
    const auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args[i] == QLatin1String("--port") && i + 1 < args.size())
            port = static_cast<quint16>(args[i + 1].toUShort());
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("vericuePort"), port);

#ifdef VERICUE_EXAMPLE_SOURCE_DIR
    engine.load(QUrl::fromLocalFile(QStringLiteral(VERICUE_EXAMPLE_SOURCE_DIR "/main.qml")));
#else
    engine.load(QUrl::fromLocalFile(
        app.applicationDirPath() + QStringLiteral("/../../../examples/touch_app/main.qml")));
#endif

    if (engine.rootObjects().isEmpty())
        engine.load(QUrl::fromLocalFile(QStringLiteral("examples/touch_app/main.qml")));

    if (engine.rootObjects().isEmpty()) {
        qCritical("Failed to load QML");
        return 1;
    }

    vericue::VeriCueServer server;
    if (!server.start(port)) {
        qCritical("Failed to start veriCue server on port %d", port);
        return 1;
    }
    qDebug("veriCue Touch demo - server on port %d", server.serverPort());

    return app.exec();
}
