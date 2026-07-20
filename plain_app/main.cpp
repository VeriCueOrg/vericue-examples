// Plain Qt application with NO veriCue linkage whatsoever.
//
// Exists as the "victim" for vericue-inject testing: it proves the injector
// can drive an application that has never heard of veriCue. Keep it that way -
// do not link vericue-server here.

#include <QApplication>
#include <QLineEdit>
#include <QMainWindow>
#include <QPushButton>
#include <QVBoxLayout>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QMainWindow window;
    window.setObjectName(QStringLiteral("PlainWindow"));
    window.setWindowTitle(QStringLiteral("Plain Qt App"));

    auto *central = new QWidget;
    central->setObjectName(QStringLiteral("centralWidget"));
    auto *layout = new QVBoxLayout(central);

    auto *input = new QLineEdit;
    input->setObjectName(QStringLiteral("plainInput"));
    input->setPlaceholderText(QStringLiteral("Nothing to see here"));
    layout->addWidget(input);

    auto *button = new QPushButton(QStringLiteral("Do nothing"));
    button->setObjectName(QStringLiteral("plainButton"));
    layout->addWidget(button);

    window.setCentralWidget(central);
    window.show();

    return app.exec();
}
