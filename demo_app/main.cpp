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

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

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

    // Start veriCue server - port from --port (0 = ephemeral), default 4242
    vericue::VeriCueServer server(&window);
    quint16 port = 4242;
    for (int i = 1; i < argc - 1; ++i) {
        if (QString::fromLatin1(argv[i]) == QLatin1String("--port"))
            port = QString::fromLatin1(argv[i + 1]).toUShort();
    }
    if (!server.start(port)) {
        qCritical("Failed to start veriCue server on port %d", port);
        return 1;
    }
    // Print the actual port so harnesses (try.sh, CI smoke) can read it.
    printf("VERICUE_PORT=%d\n", server.serverPort());
    fflush(stdout);
    qDebug("veriCue server listening on port %d", server.serverPort());

    window.show();
    return app.exec();
}
