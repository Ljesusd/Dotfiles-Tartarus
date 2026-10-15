#include "AuthController.h"
#include <QSignalSpy>
#include <QtTest>

class FakeConversation : public AuthConversation
{
public:
    using AuthConversation::AuthConversation;
    int responses = 0;
    int cancellations = 0;
    void start() override { emit requested("Password:", false); }
    void respond(const QString &) override { ++responses; }
    void cancel() override { ++cancellations; emit completed(false); }
};

class AuthTests : public QObject
{
    Q_OBJECT
private slots:
    void successAndNoDuplicateSubmission()
    {
        AuthController auth;
        FakeConversation *session = nullptr;
        QSignalSpy finished(&auth, &AuthController::finished);
        QSignalSpy cleared(&auth, &AuthController::clearResponse);
        QVERIFY(auth.begin("Message", "action", "command", {"user"}, 0,
            [&](int, QObject *parent) { return session = new FakeConversation(parent); }));
        QVERIFY(auth.active());
        QVERIFY(auth.waiting());
        QCOMPARE(auth.prompt(), QString("Contraseña"));
        auth.submit("fake-test-only");
        auth.submit("duplicate");
        QCOMPARE(session->responses, 1);
        QVERIFY(auth.busy());
        QVERIFY(!auth.waiting());
        QVERIFY(cleared.count() >= 3);
        emit session->completed(true);
        QVERIFY(!auth.active());
        QCOMPARE(finished.count(), 1);
        QCOMPARE(finished.first().first().toBool(), true);
        auth.cancel();
        QCOMPARE(finished.count(), 1);
    }

    void cancelAndLateSignals()
    {
        AuthController auth;
        FakeConversation *session = nullptr;
        QSignalSpy finished(&auth, &AuthController::finished);
        auth.begin("Message", "action", "", {"user"}, 0,
            [&](int, QObject *parent) { return session = new FakeConversation(parent); });
        auth.cancel();
        QCOMPARE(session->cancellations, 1);
        emit session->completed(true);
        emit session->requested("Late prompt", true);
        QVERIFY(!auth.active());
        QVERIFY(!auth.waiting());
        QCOMPARE(finished.count(), 1);
        QCOMPARE(finished.first().first().toBool(), false);
    }

    void retryLimitedToThreeConversations()
    {
        AuthController auth;
        FakeConversation *session = nullptr;
        QSignalSpy finished(&auth, &AuthController::finished);
        int sessions = 0;
        auth.begin("Message", "action", "", {"user"}, 0,
            [&](int, QObject *parent) { ++sessions; return session = new FakeConversation(parent); });
        for (int attempt = 0; attempt < 3; ++attempt) {
            auth.submit("test");
            emit session->error("PAM error");
            emit session->completed(false);
            if (attempt < 2) {
                QCOMPARE(auth.errorMessage(), QString("PAM error"));
                QVERIFY(auth.canRetry());
                auth.retry();
                QVERIFY(auth.waiting());
            }
        }
        QVERIFY(!auth.active());
        QVERIFY(!auth.canRetry());
        auth.retry();
        QCOMPARE(sessions, 3);
        QCOMPARE(finished.count(), 1);
    }

    void changesOnlyToOfferedIdentities()
    {
        AuthController auth;
        FakeConversation *session = nullptr;
        QList<int> selections;
        auth.begin("Message", "action", "", {"admin", "user"}, 1,
            [&](int index, QObject *parent) {
                selections.append(index);
                return session = new FakeConversation(parent);
            });
        auth.selectIdentity(-1);
        auth.selectIdentity(7);
        auth.selectIdentity(1);
        QCOMPARE(selections.size(), 1);
        auto *first = session;
        auth.selectIdentity(0);
        QCOMPARE(first->cancellations, 1);
        QCOMPARE(selections, QList<int>({1, 0}));
        QCOMPARE(auth.identityIndex(), 0);
        auth.submit("test");
        auth.selectIdentity(1); // no identity change during PAM verification
        QCOMPARE(auth.identityIndex(), 0);
    }

    void multiStepPromptsAndInfo()
    {
        AuthController auth;
        FakeConversation *session = nullptr;
        auth.begin("Message", "action", "", {"user"}, 0,
            [&](int, QObject *parent) { return session = new FakeConversation(parent); });
        auth.submit("test");
        emit session->information("Touch your authentication device");
        QCOMPARE(auth.infoMessage(), QString("Touch your authentication device"));
        emit session->requested("Verification code:", true);
        QVERIFY(auth.waiting());
        QVERIFY(auth.echo());
        QCOMPARE(auth.prompt(), QString("Verification code:"));
        auth.submit("test-code");
        QCOMPARE(session->responses, 2);
    }

    void parallelAndEmptyRequestsRejected()
    {
        AuthController auth;
        auto factory = [](int, QObject *parent) { return new FakeConversation(parent); };
        QVERIFY(!auth.begin("", "", "", {}, 0, factory));
        QVERIFY(!auth.begin("", "", "", {"user"}, 0, {}));
        QVERIFY(auth.begin("first", "first.action", "", {"user"}, 0, factory));
        QVERIFY(!auth.begin("second", "second.action", "", {"root"}, 0, factory));
        QCOMPARE(auth.message(), QString("first"));
        auth.cancel();
        QVERIFY(auth.begin("second", "second.action", "", {"root"}, 0, factory));
    }

    void failureToStartEndsRequest()
    {
        AuthController auth;
        QSignalSpy finished(&auth, &AuthController::finished);
        auth.begin("Message", "action", "", {"user"}, 0,
            [](int, QObject *) -> AuthConversation * { return nullptr; });
        QVERIFY(!auth.active());
        QCOMPARE(finished.count(), 1);
        QCOMPARE(finished.first().first().toBool(), false);
    }
};

QTEST_GUILESS_MAIN(AuthTests)
#include "tests.moc"
