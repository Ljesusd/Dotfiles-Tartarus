#pragma once

#include <QObject>
#include <QStringList>
#include <functional>

// Only this process holds the prompt/response. Production conversations delegate
// to libpolkit-agent; tests use a fake, never PAM or the user's credentials.
class AuthConversation : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    virtual void start() = 0;
    virtual void respond(const QString &response) = 0;
    virtual void cancel() = 0;
signals:
    void requested(const QString &prompt, bool echo);
    void error(const QString &message);
    void information(const QString &message);
    void completed(bool authorized);
};

class AuthController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool waiting READ waiting NOTIFY changed)
    Q_PROPERTY(bool canRetry READ canRetry NOTIFY changed)
    Q_PROPERTY(bool echo READ echo NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(QString actionId READ actionId NOTIFY changed)
    Q_PROPERTY(QString command READ command NOTIFY changed)
    Q_PROPERTY(QString prompt READ prompt NOTIFY changed)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY changed)
    Q_PROPERTY(QString infoMessage READ infoMessage NOTIFY changed)
    Q_PROPERTY(QStringList identities READ identities NOTIFY changed)
    Q_PROPERTY(int identityIndex READ identityIndex NOTIFY changed)
public:
    using Factory = std::function<AuthConversation *(int, QObject *)>;
    using QObject::QObject;
    ~AuthController() override;
    bool begin(const QString &message, const QString &actionId,
               const QString &command, const QStringList &identities,
               int selected, Factory factory);

    bool active() const { return m_active; }
    bool busy() const { return m_busy; }
    bool waiting() const { return m_waiting; }
    bool canRetry() const { return m_active && !m_conversation && m_failures < 3; }
    bool echo() const { return m_echo; }
    QString message() const { return m_message; }
    QString actionId() const { return m_actionId; }
    QString command() const { return m_command; }
    QString prompt() const { return m_prompt; }
    QString errorMessage() const { return m_error; }
    QString infoMessage() const { return m_info; }
    QStringList identities() const { return m_identities; }
    int identityIndex() const { return m_index; }

    Q_INVOKABLE void submit(const QString &response);
    Q_INVOKABLE void retry();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void selectIdentity(int index);
signals:
    void changed();
    void clearResponse();
    void promptReady();
    void finished(bool authorized);
private:
    void startConversation();
    void stopConversation();
    void finish(bool authorized);
    AuthConversation *m_conversation = nullptr;
    Factory m_factory;
    bool m_active = false;
    bool m_busy = false;
    bool m_waiting = false;
    bool m_echo = false;
    int m_failures = 0;
    int m_index = 0;
    QString m_message, m_actionId, m_command, m_prompt, m_error, m_info;
    QStringList m_identities;
};
