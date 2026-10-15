#include "AuthController.h"
#include "PolkitAgent.h"
#include <PolkitQt1/Subject>
#include <QColor>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTimer>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <unistd.h>

namespace {
QVariantMap readPalette()
{
    QVariantMap colors {
        {"background", "#171925"}, {"surface", "#20243a"},
        {"surface_container", "#20243a"}, {"surface_container_high", "#303957"},
        {"foreground", "#d9e1ff"}, {"foreground_muted", "#9ba7ca"},
        {"primary", "#83aef7"}, {"on_primary", "#171925"},
        {"outline", "#7180a7"}, {"outline_variant", "#303957"},
        {"error", "#f38ba8"}
    };
    const auto stateDir = qEnvironmentVariable("XDG_STATE_HOME",
                                               QDir::homePath() + "/.local/state");
    QFile file(stateDir + "/tartarus-shell/active-theme.json");
    if (file.size() > 128 * 1024 || !file.open(QIODevice::ReadOnly))
        return colors;
    const auto roles = QJsonDocument::fromJson(file.readAll()).object().value("roles").toObject();
    for (auto it = colors.begin(); it != colors.end(); ++it) {
        const auto value = roles.value(it.key()).toString();
        if (QColor::isValidColorName(value))
            it.value() = value;
    }
    return colors;
}

class PreviewConversation final : public AuthConversation
{
public:
    using AuthConversation::AuthConversation;
    void start() override { emit requested(QStringLiteral("Contraseña"), false); }
    void respond(const QString &) override { emit completed(false); }
    void cancel() override { emit completed(false); }
};
}

int main(int argc, char **argv)
{
    // No core dumps containing a password. This is not a root process, nor a
    // replacement for PAM; libpolkit-agent owns the privileged helper protocol.
    const rlimit noCore{0, 0};
    setrlimit(RLIMIT_CORE, &noCore);
    prctl(PR_SET_DUMPABLE, 0);
    QLoggingCategory::setFilterRules(QStringLiteral("*.debug=false"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("tartarus-polkit-agent"));
    app.setOrganizationName(QStringLiteral("Tartarus"));
    app.setDesktopFileName(QStringLiteral("org.tartarus.PolkitAgent"));
    app.setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Autenticador Polkit Qt/QML de Tartarus"));
    parser.addHelpOption();
    parser.addOption({"preview", "Vista previa sin registrar Polkit ni pedir una contraseña real."});
    parser.addOption({"check-ui", "Comprueba el QML y termina. No autentica ni registra un agente."});
    parser.process(app);
    const bool checkUi = parser.isSet("check-ui");
    const bool preview = parser.isSet("preview") || checkUi;

    AuthController controller;
    QQmlApplicationEngine engine;
    bool qmlWarning = false;
    QObject::connect(&engine, &QQmlEngine::warnings, &app, [&](const QList<QQmlError> &warnings) {
        qmlWarning = true;
        for (const auto &warning : warnings)
            qWarning().noquote() << warning.toString();
    });
    engine.setInitialProperties({{"auth", QVariant::fromValue(&controller)},
                                 {"theme", readPalette()}, {"preview", preview}});

    if (checkUi) {
        QQmlComponent component(&engine, QUrl(QStringLiteral("qrc:/Dialog.qml")));
        const auto object = component.createWithInitialProperties({
            {"auth", QVariant::fromValue(&controller)},
            {"theme", readPalette()}, {"preview", true}
        });
        if (component.isError()) {
            for (const auto &error : component.errors())
                qCritical().noquote() << error.toString();
            delete object;
            return 1;
        }
        delete object;
        return 0;
    }

    engine.load(QUrl(QStringLiteral("qrc:/Dialog.qml")));
    if (engine.rootObjects().isEmpty()) {
        qCritical("No se pudo cargar el autenticador QML; se mantiene el agente de respaldo.");
        return 1;
    }
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!window)
        return 1;
    bool wasActive = false;
    QObject::connect(&controller, &AuthController::changed, &app, [&] {
        if (controller.active() && !wasActive) {
            window->setProperty("theme", readPalette());
            QTimer::singleShot(0, window, [window] { window->requestActivate(); });
        }
        wasActive = controller.active();
    });
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &controller, &AuthController::cancel);

    if (preview) {
        QObject::connect(&controller, &AuthController::finished, &app, &QCoreApplication::quit);
        controller.begin(QStringLiteral("Se necesita autorización para instalar o actualizar aplicaciones."),
                         QStringLiteral("org.freedesktop.policykit.exec"),
                         QStringLiteral("/usr/bin/pacman -Syu"),
                         {qEnvironmentVariable("USER", "Usuario")}, 0,
                         [](int, QObject *parent) { return new PreviewConversation(parent); });
        return app.exec();
    }

    // Resolve the graphical login session even when launched via systemd/SSH.
    const auto sessionId = qEnvironmentVariable("XDG_SESSION_ID");
    const auto subject = sessionId.isEmpty()
        ? PolkitQt1::UnixSessionSubject(qint64(getpid()))
        : PolkitQt1::UnixSessionSubject(sessionId);
    if (!subject.isValid()) {
        qCritical("No se pudo identificar la sesión gráfica para Polkit.");
        return 1;
    }
    auto sessionBus = QDBusConnection::sessionBus();
    // A marker for single-instance/readiness only. No password, response method,
    // controller or QML object is exported to the session bus.
    const QString busName = QStringLiteral("org.tartarus.PolkitAgent");
    if (!sessionBus.isConnected() || !sessionBus.registerService(busName)) {
        qCritical("Ya existe un agente Tartarus o no está disponible el bus de sesión.");
        return 1;
    }
    PolkitAgent agent(&controller);
    if (!agent.registerListener(subject, QStringLiteral("/org/tartarus/PolicyKit1/AuthenticationAgent")))
        return 1;

    QDBusServiceWatcher authority(QStringLiteral("org.freedesktop.PolicyKit1"),
        QDBusConnection::systemBus(), QDBusServiceWatcher::WatchForUnregistration);
    QObject::connect(&authority, &QDBusServiceWatcher::serviceUnregistered, &app, [&] {
        controller.cancel();
        app.exit(1); // the supervisor can restore a fallback after a daemon restart
    });
    qInfo("Autenticador Tartarus registrado para la sesión gráfica.");
    return app.exec();
}
