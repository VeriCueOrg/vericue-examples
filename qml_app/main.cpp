#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>

#include "vericue/server.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("veriCue QML Demo"));

    // Parse port from command line
    quint16 port = 4243;
    const auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args[i] == QLatin1String("--port") && i + 1 < args.size())
            port = static_cast<quint16>(args[i + 1].toUShort());
    }

    QQmlApplicationEngine engine;

    // Expose port to QML for status bar display
    engine.rootContext()->setContextProperty(QStringLiteral("vericuePort"), port);

#ifdef VERICUE_EXAMPLE_SOURCE_DIR
    engine.load(QUrl::fromLocalFile(QStringLiteral(VERICUE_EXAMPLE_SOURCE_DIR "/main.qml")));
#else
    engine.load(QUrl::fromLocalFile(
        app.applicationDirPath() + QStringLiteral("/../../../examples/qml_app/main.qml")));
#endif

    if (engine.rootObjects().isEmpty()) {
        // Try relative path as fallback
        engine.load(QUrl::fromLocalFile(QStringLiteral("examples/qml_app/main.qml")));
    }

    if (engine.rootObjects().isEmpty()) {
        qCritical("Failed to load QML");
        return 1;
    }

    // Start veriCue server
    vericue::VeriCueServer server;
    if (!server.start(port)) {
        qCritical("Failed to start veriCue server on port %d", port);
        return 1;
    }
    qDebug("veriCue QML demo running - server on port %d", server.serverPort());

    return app.exec();
}
