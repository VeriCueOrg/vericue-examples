#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QPushButton>
#include <QLabel>
#include <QLineEdit>
#include <QCheckBox>
#include <QTimer>
#include <QDebug>

#include "vericue/server.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QMainWindow window;
    window.setObjectName(QStringLiteral("TestWindow"));
    window.setWindowTitle(QStringLiteral("veriCue Test App"));
    window.resize(400, 300);

    auto *central = new QWidget;
    central->setObjectName(QStringLiteral("centralWidget"));

    auto *layout = new QVBoxLayout(central);

    auto *label = new QLabel(QStringLiteral("Test Label"));
    label->setObjectName(QStringLiteral("testLabel"));
    layout->addWidget(label);

    auto *lineEdit = new QLineEdit;
    lineEdit->setObjectName(QStringLiteral("testInput"));
    layout->addWidget(lineEdit);

    auto *button = new QPushButton(QStringLiteral("Click Me"));
    button->setObjectName(QStringLiteral("testButton"));
    layout->addWidget(button);

    auto *checkbox = new QCheckBox(QStringLiteral("Check Me"));
    checkbox->setObjectName(QStringLiteral("testCheckbox"));
    layout->addWidget(checkbox);

    window.setCentralWidget(central);

    // Start veriCue server on port from args or default 14242
    quint16 port = 14242;
    for (int i = 1; i < argc; ++i) {
        if (QString::fromLatin1(argv[i]) == QLatin1String("--port") && i + 1 < argc)
            port = QString::fromLatin1(argv[i + 1]).toUShort();
    }

    vericue::VeriCueServer server(&window);
    if (!server.start(port)) {
        qCritical("Failed to start server on port %d", port);
        return 1;
    }

    // Print port to stdout so test harness can read it
    printf("VERICUE_PORT=%d\n", server.serverPort());
    fflush(stdout);

    window.show();
    return app.exec();
}
