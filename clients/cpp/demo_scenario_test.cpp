// The canonical veriCue scenario, in C++ (GoogleTest + the shipped client).
//
// The identical four steps exist in Python (clients/python) and C#
// (clients/csharp):
//
//   1. address a stable object and check what it is;
//   2. drive a text input and read the resulting property;
//   3. click a checkbox and check the state actually changed;
//   4. capture a screenshot as a retained artifact.
//
// Two fixtures run them, one per transport:
//
//   DemoScenarioTest    the fixture shipped in the SDK
//                       (<vericue/gtest_fixture.h>), which connects over TCP
//                       using VERICUE_HOST / VERICUE_PORT / VERICUE_TOKEN.
//   LocalEndpointTest   defined here, ~40 lines on top of VeriCueClient, for
//                       the local IPC transport. v0.4.0's shipped fixture is
//                       TCP-only; VeriCueClient::connectToLocalServer() is
//                       not, so a local endpoint needs this much wiring and
//                       no more.
//
// The four steps themselves are written once, against an `Invoker` - the one
// operation both fixtures provide - so the two transports really do run the
// same scenario. clients/cpp/run.sh starts demo_app on each transport in turn
// and selects the matching suite with --gtest_filter.

#include <vericue/client.h>
#include <vericue/gtest_fixture.h>

#include <gtest/gtest.h>

#include <QByteArray>
#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QString>

#include <functional>

namespace {

// Object paths in demo_app (examples/demo_app/main.cpp). Every widget there is
// given an explicit objectName, which is what makes these paths stable.
const QString kWindow = QStringLiteral("DemoMainWindow");
const QString kInput = QStringLiteral("DemoMainWindow/centralWidget/inputField");
const QString kCheckbox = QStringLiteral("DemoMainWindow/centralWidget/enableCheck");
const QString kTypedText = QStringLiteral("vericue");

// One veriCue request: method + params -> result object. Both fixtures below
// expose exactly this.
using Invoker = std::function<QJsonObject(const QString &, const QJsonObject &)>;

// Where screenshots and other retained evidence go. CI overrides it with
// VERICUE_ARTIFACT_DIR and uploads the contents; see clients/ci/run.sh.
QString artifactDir()
{
    const QString path = qEnvironmentVariable("VERICUE_ARTIFACT_DIR",
                                              QStringLiteral("vericue-artifacts"));
    QDir().mkpath(path);
    return path;
}

// --- the scenario -----------------------------------------------------------

// 1. The object path resolves, and to the class we expect.
void objectIsAddressable(const Invoker &invoke)
{
    const QJsonObject found = invoke(QStringLiteral("find_object"),
                                     QJsonObject{{QStringLiteral("path"), kCheckbox}});
    EXPECT_EQ(found[QStringLiteral("className")].toString(), QStringLiteral("QCheckBox"));
    EXPECT_EQ(found[QStringLiteral("path")].toString(), kCheckbox);
}

// 2. Input action: real key events, then read the property back.
void typingUpdatesTheTextProperty(const Invoker &invoke)
{
    // Start from a known value, so the assertion is an equality and not a
    // "ends with" - type_text appends at the cursor like a user would.
    invoke(QStringLiteral("set_property"), QJsonObject{
        {QStringLiteral("path"), kInput},
        {QStringLiteral("property"), QStringLiteral("text")},
        {QStringLiteral("value"), QString()},
    });

    invoke(QStringLiteral("type_text"), QJsonObject{
        {QStringLiteral("path"), kInput},
        {QStringLiteral("text"), kTypedText},
    });

    // get_properties answers {path, className, properties:{...}}.
    const QJsonObject result = invoke(QStringLiteral("get_properties"), QJsonObject{
        {QStringLiteral("path"), kInput},
        {QStringLiteral("properties"), QJsonArray{QStringLiteral("text")}},
    });
    EXPECT_EQ(result[QStringLiteral("properties")].toObject()[QStringLiteral("text")].toString(),
              kTypedText);
}

// 3. State change: assert against the state before the click.
void clickTogglesTheCheckbox(const Invoker &invoke)
{
    const QJsonObject query{
        {QStringLiteral("path"), kCheckbox},
        {QStringLiteral("properties"), QJsonArray{QStringLiteral("checked")}},
    };
    const bool before = invoke(QStringLiteral("get_properties"), query)[QStringLiteral("properties")]
                            .toObject()[QStringLiteral("checked")].toBool();

    invoke(QStringLiteral("mouse_click"), QJsonObject{{QStringLiteral("path"), kCheckbox}});

    const bool after = invoke(QStringLiteral("get_properties"), query)[QStringLiteral("properties")]
                           .toObject()[QStringLiteral("checked")].toBool();
    EXPECT_NE(after, before);
}

// 4. Screenshot of the window, written where CI can retain it.
void screenshotIsCaptured(const Invoker &invoke)
{
    const QJsonObject shot = invoke(QStringLiteral("screenshot"),
                                    QJsonObject{{QStringLiteral("path"), kWindow}});
    const QByteArray png =
        QByteArray::fromBase64(shot[QStringLiteral("data")].toString().toUtf8());

    const QString out = artifactDir() + QStringLiteral("/demo_app-cpp.png");
    QFile file(out);
    ASSERT_TRUE(file.open(QIODevice::WriteOnly)) << "cannot write " << qUtf8Printable(out);
    file.write(png);
    file.close();

    EXPECT_GT(shot[QStringLiteral("width")].toInt(), 0);
    EXPECT_GT(shot[QStringLiteral("height")].toInt(), 0);
    // PNG magic - proves the bytes survived the base64 round trip.
    EXPECT_TRUE(png.startsWith(QByteArray("\x89PNG\r\n\x1a\n", 8)));
    EXPECT_GT(QFile(out).size(), 0);
}

// --- local IPC fixture ------------------------------------------------------

// What the shipped fixture does for TCP, for a local endpoint. Same client,
// same protocol, same commands - only connectToLocalServer() differs.
class LocalEndpointTest : public ::testing::Test {
protected:
    void SetUp() override
    {
        const QString endpoint = qEnvironmentVariable("VERICUE_ENDPOINT");
        if (endpoint.isEmpty())
            GTEST_SKIP() << "VERICUE_ENDPOINT is not set - start demo_app with "
                            "--endpoint (see clients/cpp/run.sh)";

        if (!QCoreApplication::instance()) {
            static int argc = 0;
            static char *argv = nullptr;
            new QCoreApplication(argc, &argv);
        }

        m_client = new vericue::VeriCueClient;
        bool connected = false;
        QString error;
        QObject::connect(m_client, &vericue::VeriCueClient::connected,
                         m_client, [&] { connected = true; });
        QObject::connect(m_client, &vericue::VeriCueClient::connectionError,
                         m_client, [&](const QString &e) { error = e; });

        m_client->connectToLocalServer(endpoint, qEnvironmentVariable("VERICUE_TOKEN"));

        QElapsedTimer timer;
        timer.start();
        while (!connected && error.isEmpty() && timer.elapsed() < 5000)
            QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        ASSERT_TRUE(connected) << "cannot connect to " << qUtf8Printable(endpoint) << ": "
                               << qUtf8Printable(error);
    }

    void TearDown() override
    {
        if (m_client) {
            m_client->disconnectFromServer();
            delete m_client;
            m_client = nullptr;
        }
        QCoreApplication::processEvents();
    }

    // Send one request and block until its response arrives.
    Invoker invoker()
    {
        return [this](const QString &method, const QJsonObject &params) {
            QJsonObject result;
            bool done = false;
            QString failure;
            const QString id = m_client->sendRequest(method, params);
            auto ok = QObject::connect(m_client, &vericue::VeriCueClient::responseReceived,
                                       m_client, [&](const QString &rid, const QJsonObject &r) {
                                           if (rid == id) { result = r; done = true; }
                                       });
            auto bad = QObject::connect(m_client, &vericue::VeriCueClient::errorReceived,
                                        m_client, [&](const QString &rid, int code, const QString &msg) {
                                            if (rid == id) {
                                                failure = QStringLiteral("%1: %2").arg(code).arg(msg);
                                                done = true;
                                            }
                                        });
            QElapsedTimer timer;
            timer.start();
            while (!done && timer.elapsed() < 5000)
                QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
            QObject::disconnect(ok);
            QObject::disconnect(bad);
            if (!failure.isEmpty())
                throw vericue::CommandFailed(-1, failure);
            EXPECT_TRUE(done) << "timed out waiting for " << qUtf8Printable(method);
            return result;
        };
    }

private:
    vericue::VeriCueClient *m_client = nullptr;
};

// --- TCP fixture: the one shipped in the SDK --------------------------------

class DemoScenarioTest : public vericue::VeriCueTest {
protected:
    Invoker invoker()
    {
        return [this](const QString &method, const QJsonObject &params) {
            return invoke(method, params);
        };
    }
};

TEST_F(DemoScenarioTest, ObjectIsAddressable) { objectIsAddressable(invoker()); }
TEST_F(DemoScenarioTest, TypingUpdatesTheTextProperty) { typingUpdatesTheTextProperty(invoker()); }
TEST_F(DemoScenarioTest, ClickTogglesTheCheckbox) { clickTogglesTheCheckbox(invoker()); }
TEST_F(DemoScenarioTest, ScreenshotIsCaptured) { screenshotIsCaptured(invoker()); }

// One connection, all four steps: a local endpoint is per-process and the
// scenario is what is being proven here, not the fixture.
TEST_F(LocalEndpointTest, CanonicalScenario)
{
    const Invoker invoke = invoker();
    objectIsAddressable(invoke);
    typingUpdatesTheTextProperty(invoke);
    clickTogglesTheCheckbox(invoke);
    screenshotIsCaptured(invoke);
}

} // namespace
