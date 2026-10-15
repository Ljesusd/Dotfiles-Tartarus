#include "PolkitAgent.h"
#include <PolkitQt1/Agent/Session>
#include <PolkitQt1/Details>
#include <pwd.h>
#include <unistd.h>

namespace {
class PolkitConversation final : public AuthConversation
{
public:
    PolkitConversation(const PolkitQt1::Identity &identity, const QString &cookie, QObject *parent)
        : AuthConversation(parent), session(identity, cookie, nullptr, this)
    {
        connect(&session, &PolkitQt1::Agent::Session::request, this, &AuthConversation::requested);
        connect(&session, &PolkitQt1::Agent::Session::showError, this, &AuthConversation::error);
        connect(&session, &PolkitQt1::Agent::Session::showInfo, this, &AuthConversation::information);
        connect(&session, &PolkitQt1::Agent::Session::completed, this, &AuthConversation::completed);
    }
    void start() override { session.initiate(); }
    void respond(const QString &response) override { session.setResponse(response); }
    void cancel() override { session.cancel(); }
private:
    PolkitQt1::Agent::Session session;
};
}

PolkitAgent::PolkitAgent(AuthController *controller) : m_controller(controller)
{
    connect(controller, &AuthController::finished, this, [this](bool) {
        // The official helper conveys authorization to polkitd. UI state NEVER
        // grants privileges: completing the result merely ends the conversation.
        auto result = std::move(m_result);
        if (result)
            result->setCompleted();
    });
}

PolkitAgent::~PolkitAgent()
{
    m_controller->cancel();
}

void PolkitAgent::initiateAuthentication(const QString &actionId, const QString &message,
    const QString &, const PolkitQt1::Details &details, const QString &cookie,
    const PolkitQt1::Identity::List &identities, PolkitQt1::Agent::AsyncResult *rawResult)
{
    std::unique_ptr<PolkitQt1::Agent::AsyncResult> result(rawResult);
    if (m_result || m_controller->active() || identities.isEmpty()) {
        result->setError(QStringLiteral("Otro diálogo de autenticación está abierto o no hay identidades válidas."));
        result->setCompleted();
        return;
    }
    QStringList names;
    int selected = 0;
    for (auto identity : identities) {
        const auto user = identity.toUnixUserIdentity();
        QString name = identity.toString();
        if (user.isValid()) {
            if (const auto *entry = getpwuid(user.uid()))
                name = QString::fromLocal8Bit(entry->pw_name);
            if (user.uid() == getuid())
                selected = int(names.size());
        }
        names.append(name);
    }
    QString command = details.lookup(QStringLiteral("command_line"));
    if (command.isEmpty())
        command = details.lookup(QStringLiteral("program"));
    m_result = std::move(result);
    if (!m_controller->begin(message, actionId, command, names, selected,
            [identities, cookie](int index, QObject *parent) {
                return new PolkitConversation(identities.at(index), cookie, parent);
            })) {
        m_result->setError(QStringLiteral("No se pudo abrir el diálogo de autenticación."));
        m_result->setCompleted();
        m_result.reset();
    }
}

void PolkitAgent::cancelAuthentication()
{
    m_controller->cancel();
}
