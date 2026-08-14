// veriCue demo application - the host for the "embedded" example flows.
//
// Transport is chosen on the command line:
//
//   (no arguments)      TCP on port 4242              -> prints VERICUE_PORT=4242
//   --port N            TCP on port N (0 = ephemeral) -> prints VERICUE_PORT=<actual>
//   --endpoint [PATH]   local IPC, Linux/macOS only   -> prints VERICUE_ENDPOINT=<path>
//   --token TOKEN       require TOKEN in the client handshake
//
// --endpoint needs veriCue v0.4.0 or newer: VeriCueServer::startLocal() does not
// exist in v0.3.5, and this file keeps compiling against it
// (the CMake check in ../CMakeLists.txt defines VERICUE_EXAMPLES_HAS_LOCAL_IPC
// only when the veriCue headers being built against expose startLocal()).
//
// The announcement line on stdout is the contract the flow scripts under
// ../flows/ rely on: no fixed port, no fixed socket path, no sleeping.

#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLabel>
#include <QLineEdit>
#include <QCheckBox>
#include <QProgressBar>
#include <QMenuBar>
#include <QStatusBar>
#include <QDebug>

#include "vericue/server.h"

#include <cstdio>

namespace {

struct Options {
    bool localIpc = false;  // --endpoint given: local IPC instead of TCP
    QString endpoint;       // optional explicit endpoint path
    bool portGiven = false;
    quint16 port = 4242;    // --port, 0 lets the OS pick a free port
    QString token;          // --token
};

void printUsage()
{
    fprintf(stderr,
            "usage: vericue-demo-app [--port N | --endpoint [PATH]] [--token TOKEN]\n"
            "  --port N           TCP port to listen on, 0 = ephemeral.\n"
            "                     Announced on stdout as VERICUE_PORT=<n>.\n"
            "  --endpoint [PATH]  Local IPC endpoint (Linux/macOS only). Without PATH\n"
            "                     veriCue picks a user-private per-process socket.\n"
            "                     Announced on stdout as VERICUE_ENDPOINT=<path>.\n"
            "  --token TOKEN      Require TOKEN in the client handshake.\n"
            "Without arguments the app listens on TCP port 4242.\n");
}

bool parseOptions(const QStringList &args, Options *opts)
{
    for (int i = 1; i < args.size(); ++i) {
        const QString arg = args.at(i);
        if (arg == QLatin1String("--port")) {
            if (i + 1 >= args.size())
                return false;
            bool ok = false;
            const uint value = args.at(++i).toUInt(&ok);
            if (!ok || value > 65535)
                return false;
            opts->port = static_cast<quint16>(value);
            opts->portGiven = true;
        } else if (arg == QLatin1String("--endpoint")) {
            opts->localIpc = true;
            // The path is optional - an argument is only consumed when it does
            // not look like the next option.
            if (i + 1 < args.size() && !args.at(i + 1).startsWith(QLatin1String("--")))
                opts->endpoint = args.at(++i);
        } else if (arg == QLatin1String("--token")) {
            if (i + 1 >= args.size())
                return false;
            opts->token = args.at(++i);
        } else {
            return false;
        }
    }
    // One transport per run keeps the example (and its stdout contract)
    // unambiguous, even though VeriCueServer can serve both at once.
    return !(opts->localIpc && opts->portGiven);
}

} // namespace

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    Options opts;
    if (!parseOptions(app.arguments(), &opts)) {
        printUsage();
        return 2;
    }

    QMainWindow window;
    window.setObjectName(QStringLiteral("DemoMainWindow"));
    window.setWindowTitle(QStringLiteral("veriCue Demo"));

    // Central widget
    auto *central = new QWidget;
    central->setObjectName(QStringLiteral("centralWidget"));

    auto *layout = new QVBoxLayout(central);

    auto *headerLabel = new QLabel(QStringLiteral("veriCue Demo App"));
    headerLabel->setObjectName(QStringLiteral("headerLabel"));
    layout->addWidget(headerLabel);

    auto *inputField = new QLineEdit;
    inputField->setObjectName(QStringLiteral("inputField"));
    inputField->setPlaceholderText(QStringLiteral("Type here..."));
    layout->addWidget(inputField);

    auto *buttonLayout = new QHBoxLayout;
    auto *okButton = new QPushButton(QStringLiteral("OK"));
    okButton->setObjectName(QStringLiteral("okButton"));
    auto *cancelButton = new QPushButton(QStringLiteral("Cancel"));
    cancelButton->setObjectName(QStringLiteral("cancelButton"));
    buttonLayout->addWidget(okButton);
    buttonLayout->addWidget(cancelButton);
    layout->addLayout(buttonLayout);

    auto *enableCheck = new QCheckBox(QStringLiteral("Enable feature"));
    enableCheck->setObjectName(QStringLiteral("enableCheck"));
    layout->addWidget(enableCheck);

    auto *progressBar = new QProgressBar;
    progressBar->setObjectName(QStringLiteral("progressBar"));
    progressBar->setValue(42);
    layout->addWidget(progressBar);

    window.setCentralWidget(central);

    // Menus
    auto *fileMenu = window.menuBar()->addMenu(QStringLiteral("File"));
    fileMenu->setObjectName(QStringLiteral("fileMenu"));
    auto *editMenu = window.menuBar()->addMenu(QStringLiteral("Edit"));
    editMenu->setObjectName(QStringLiteral("editMenu"));

    // Status bar
    window.statusBar()->setObjectName(QStringLiteral("statusBar"));
    window.statusBar()->showMessage(QStringLiteral("Ready"));

    // Start the veriCue Runtime inside this process.
    vericue::VeriCueServer server(&window);
    // startLocal()/start() report why they failed through this signal, so wire
    // it up before starting anything.
    QObject::connect(&server, &vericue::VeriCueServer::errorOccurred,
                     &server, [](const QString &error) {
                         fprintf(stderr, "veriCue: %s\n", qUtf8Printable(error));
                     });

    if (!opts.token.isEmpty())
        server.setAuthToken(opts.token);

    if (opts.localIpc) {
#ifdef VERICUE_EXAMPLES_HAS_LOCAL_IPC
        // Local IPC: a user-private UNIX socket with no network presence.
        // Linux and macOS only - on Windows use --port.
        if (!server.startLocal(opts.endpoint)) {
            qCritical("Failed to start the veriCue Runtime on a local endpoint");
            return 1;
        }
        // Print the resolved endpoint so harnesses can read it instead of
        // guessing the socket path.
        printf("VERICUE_ENDPOINT=%s\n", qUtf8Printable(server.localEndpoint()));
        fflush(stdout);
        qDebug("veriCue Runtime listening on local endpoint %s",
               qUtf8Printable(server.localEndpoint()));
#else
        fprintf(stderr,
                "vericue-demo-app: --endpoint needs veriCue v0.4.0 or newer "
                "(VeriCueServer::startLocal() is missing from the veriCue headers this "
                "binary was built against). Use --port for the TCP transport.\n");
        return 2;
#endif
    } else {
        if (!server.start(opts.port)) {
            qCritical("Failed to start the veriCue Runtime on port %d", opts.port);
            return 1;
        }
        // Print the actual port so harnesses (try.sh, CI smoke) can read it -
        // it is the only way to learn the port picked by --port 0.
        printf("VERICUE_PORT=%d\n", server.serverPort());
        fflush(stdout);
        qDebug("veriCue Runtime listening on TCP port %d", server.serverPort());
    }

    window.show();
    return app.exec();
}
