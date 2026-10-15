#pragma once

#include "AuthController.h"
#include <PolkitQt1/Agent/Listener>
#include <memory>

class PolkitAgent : public PolkitQt1::Agent::Listener
{
    Q_OBJECT
public:
    explicit PolkitAgent(AuthController *controller);
    ~PolkitAgent() override;
    void initiateAuthentication(const QString &actionId, const QString &message,
        const QString &iconName, const PolkitQt1::Details &details,
        const QString &cookie, const PolkitQt1::Identity::List &identities,
        PolkitQt1::Agent::AsyncResult *result) override;
    bool initiateAuthenticationFinish() override { return true; }
    void cancelAuthentication() override;
private:
    AuthController *m_controller;
    std::unique_ptr<PolkitQt1::Agent::AsyncResult> m_result;
};
