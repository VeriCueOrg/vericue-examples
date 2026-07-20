#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QTabWidget>
#include <QTableView>
#include <QTreeView>
#include <QListView>
#include <QStandardItemModel>
#include <QHeaderView>
#include <QLabel>
#include <QStatusBar>
#include <QDebug>

#include "vericue/server.h"

static QStandardItemModel *createEmployeeModel(QObject *parent)
{
    auto *model = new QStandardItemModel(0, 4, parent);
    model->setHorizontalHeaderLabels({"Name", "Department", "Salary", "City"});

    struct Row { QString name, dept; int salary; QString city; };
    QList<Row> data = {
        {"Alice Johnson",   "Engineering",  120000, "San Francisco"},
        {"Bob Smith",       "Marketing",     85000, "New York"},
        {"Carol Williams",  "Engineering",  115000, "Seattle"},
        {"David Brown",     "Sales",         92000, "Chicago"},
        {"Eve Davis",       "Engineering",  130000, "San Francisco"},
        {"Frank Miller",    "Marketing",     78000, "Boston"},
        {"Grace Wilson",    "Sales",         88000, "Los Angeles"},
        {"Henry Taylor",    "Engineering",  125000, "Seattle"},
        {"Ivy Anderson",    "Marketing",     82000, "New York"},
        {"Jack Thomas",     "Sales",         95000, "Chicago"},
        {"Karen Martinez",  "Engineering",  118000, "San Francisco"},
        {"Leo Garcia",      "Sales",         91000, "Los Angeles"},
    };

    for (const auto &r : data) {
        QList<QStandardItem *> items;
        items << new QStandardItem(r.name);
        items << new QStandardItem(r.dept);
        items << new QStandardItem(QString::number(r.salary));
        items << new QStandardItem(r.city);
        model->appendRow(items);
    }

    return model;
}

static QStandardItemModel *createTreeModel(QObject *parent)
{
    auto *model = new QStandardItemModel(parent);
    model->setHorizontalHeaderLabels({"Name", "Size"});

    auto addFolder = [](QStandardItem *parent, const QString &name,
                        const QList<QPair<QString, QString>> &files) {
        auto *folder = new QStandardItem(name);
        auto *sizeItem = new QStandardItem("");
        parent->appendRow({folder, sizeItem});
        for (const auto &f : files) {
            folder->appendRow({new QStandardItem(f.first), new QStandardItem(f.second)});
        }
        return folder;
    };

    auto *root = model->invisibleRootItem();
    addFolder(root, "src", {{"main.cpp", "2.4 KB"}, {"app.h", "1.1 KB"}, {"app.cpp", "5.8 KB"}});
    addFolder(root, "tests", {{"test_main.cpp", "3.2 KB"}, {"test_utils.cpp", "1.9 KB"}});
    addFolder(root, "docs", {{"README.md", "4.5 KB"}, {"API.md", "12.3 KB"}});

    return model;
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QMainWindow window;
    window.setObjectName(QStringLiteral("MainWindow"));
    window.setWindowTitle(QStringLiteral("veriCue Table Demo"));
    window.resize(700, 500);

    auto *central = new QWidget;
    central->setObjectName(QStringLiteral("centralWidget"));

    auto *layout = new QVBoxLayout(central);

    auto *header = new QLabel(QStringLiteral("Model/View Data Access Demo"));
    header->setObjectName(QStringLiteral("headerLabel"));
    header->setStyleSheet(QStringLiteral("font-size: 16px; font-weight: bold; padding: 8px;"));
    layout->addWidget(header);

    auto *tabs = new QTabWidget;
    tabs->setObjectName(QStringLiteral("tabWidget"));

    // ── Tab 1: Table View ──
    auto *tableView = new QTableView;
    tableView->setObjectName(QStringLiteral("employeeTable"));
    auto *empModel = createEmployeeModel(tableView);
    empModel->setObjectName(QStringLiteral("employeeModel"));
    tableView->setModel(empModel);
    tableView->horizontalHeader()->setStretchLastSection(true);
    tableView->setSelectionBehavior(QAbstractItemView::SelectRows);
    tableView->setAlternatingRowColors(true);
    tabs->addTab(tableView, QStringLiteral("Employees (Table)"));

    // ── Tab 2: Tree View ──
    auto *treeView = new QTreeView;
    treeView->setObjectName(QStringLiteral("fileTree"));
    auto *treeModel = createTreeModel(treeView);
    treeModel->setObjectName(QStringLiteral("fileModel"));
    treeView->setModel(treeModel);
    treeView->expandAll();
    treeView->header()->setStretchLastSection(true);
    tabs->addTab(treeView, QStringLiteral("Files (Tree)"));

    // ── Tab 3: List View ──
    auto *listView = new QListView;
    listView->setObjectName(QStringLiteral("cityList"));
    auto *listModel = new QStandardItemModel(listView);
    listModel->setObjectName(QStringLiteral("cityModel"));
    for (const auto &city : {"San Francisco", "New York", "Seattle", "Chicago",
                             "Boston", "Los Angeles", "Austin", "Denver"}) {
        listModel->appendRow(new QStandardItem(QString::fromLatin1(city)));
    }
    listView->setModel(listModel);
    tabs->addTab(listView, QStringLiteral("Cities (List)"));

    layout->addWidget(tabs);
    window.setCentralWidget(central);

    window.statusBar()->setObjectName(QStringLiteral("statusBar"));
    window.statusBar()->showMessage(QStringLiteral("Ready - 12 employees, 8 files, 8 cities"));

    // Start veriCue server
    quint16 port = 4245;
    const auto args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args[i] == QLatin1String("--port") && i + 1 < args.size())
            port = static_cast<quint16>(args[i + 1].toUShort());
    }

    vericue::VeriCueServer server(&window);
    if (!server.start(port)) {
        qCritical("Failed to start veriCue server on port %d", port);
        return 1;
    }
    qDebug("veriCue Table demo - server on port %d", server.serverPort());

    window.show();
    return app.exec();
}
