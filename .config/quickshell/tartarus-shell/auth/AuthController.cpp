#include "AuthController.h"
#include <utility>

AuthController::~AuthController()
{
    stopConversation();
}

bool AuthController::begin(const QString &message, const QString &actionId,
                           const QString &command, const QStringList &identities,
                           int selected, Factory factory)
{
    if (m_active || identities.isEmpty() || !factory)
        return false;
    m_factory = std::move(factory);
    m_message = message;
    m_actionId = actionId;
    m_command = command;
    m_identities = identities;
    m_index = qBound(0, selected, int(identities.size()) - 1);
    m_failures = 0;
    m_error.clear();
    m_info.clear();
    m_active = true;
    startConversation();
    return true;
}

void AuthController::startConversation()
{
    m_waiting = false;
    m_echo = false;
    m_busy = true;
    m_prompt.clear();
    emit clearResponse();
    m_conversation = m_factory(m_index, this);
    if (!m_conversation) {
        finish(false);
        return;
    }
    connect(m_conversation, &AuthConversation::requested, this,
            [this](const QString &prompt, bool echo) {
        m_prompt = prompt.trimmed();
        if (m_prompt.compare(QStringLiteral("Password:"), Qt::CaseInsensitive) == 0)
            m_prompt = QStringLiteral("Contraseña");
        m_echo = echo;
        m_waiting = true;
        m_busy = false;
        emit clearResponse();
        emit changed();
        emit promptReady();
    });
    connect(m_conversation, &AuthConversation::error, this, [this](const QString &text) {
        m_error = text;
        emit changed();
    });
    connect(m_conversation, &AuthConversation::information, this, [this](const QString &text) {
        m_info = text;
        emit changed();
    });
    connect(m_conversation, &AuthConversation::completed, this, [this](bool authorized) {
        auto *completed = std::exchange(m_conversation, nullptr);
        completed->disconnect(this);
        completed->deleteLater();
        m_waiting = false;
        m_busy = false;
        emit clearResponse();
        if (authorized) {
            finish(true);
        } else {
            ++m_failures;
            if (m_error.isEmpty())
                m_error = QStringLiteral("No se pudo autenticar. Comprueba tus credenciales.");
            if (m_failures >= 3)
                finish(false);
            else
                emit changed();
        }
    });
    emit changed();
    m_conversation->start();
}

void AuthController::submit(const QString &response)
{
    if (!m_active || !m_waiting || m_busy || !m_conversation)
        return;
    m_waiting = false;
    m_busy = true;
    m_error.clear();
    m_info.clear();
    emit changed();
    // Do not cache, log, put on D-Bus, or execute this response as a command.
    m_conversation->respond(response);
    emit clearResponse();
}

void AuthController::retry()
{
    if (!canRetry())
        return;
    m_error.clear();
    m_info.clear();
    startConversation();
}

void AuthController::selectIdentity(int index)
{
    if (!m_active || m_busy || index == m_index || index < 0 || index >= m_identities.size())
        return;
    stopConversation();
    m_index = index;
    m_error.clear();
    m_info.clear();
    // Changing identity must not reset the request's retry limit.
    startConversation();
}

void AuthController::stopConversation()
{
    auto *session = std::exchange(m_conversation, nullptr);
    if (!session)
        return;
    session->disconnect(this);
    connect(session, &AuthConversation::completed, session, &QObject::deleteLater);
    session->cancel();
    // deleteLater is safe even if cancel() completed synchronously.
    session->deleteLater();
}

void AuthController::finish(bool authorized)
{
    if (!m_active)
        return;
    m_active = false;
    stopConversation();
    m_waiting = false;
    m_busy = false;
    m_factory = {}; // release the authentication cookie and offered identities
    emit clearResponse();
    emit changed();
    emit finished(authorized);
}

void AuthController::cancel()
{
    finish(false);
}
