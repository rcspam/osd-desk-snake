#include "presetlibrary.h"
#include "settingsservice.h"
#include "settingsstore.h"

#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <KWindowSystem>

#include <QApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QUrl>
#include <QWindow>

// Page asked by the osd-desk-snake:// link that started the app (osd-desk-snake://presets).
static QString pageFromArguments(const QStringList &arguments)
{
    for (const QString &argument : arguments.mid(1)) {
        const QUrl url(argument);
        if (url.scheme() == QLatin1String("osd-desk-snake")) {
            return url.host();
        }
    }
    return {};
}

int main(int argc, char **argv)
{
    // QApplication rather than QGuiApplication: the color picker may use a widget dialog.
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("osd-desk-snake");
    app.setApplicationName(QStringLiteral("osd-desk-snake-settings"));
    app.setApplicationDisplayName(i18n("OSD Desk Snake settings"));
    // Also the Wayland app id; the KWin script recognizes this window by it.
    app.setDesktopFileName(QStringLiteral("osd-desk-snake-settings"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("virtual-desktops")));

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    const QString page = pageFromArguments(app.arguments());

    // Single instance: two stores would overwrite each other, and the KWin script
    // talks to whichever owns the bus name.
    const QString serviceName = QStringLiteral("org.kde.osddesksnake.settings");
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(serviceName)) {
        QDBusMessage activate = QDBusMessage::createMethodCall(serviceName,
                                                               QStringLiteral("/Settings"),
                                                               QStringLiteral("org.kde.osddesksnake.Settings"),
                                                               QStringLiteral("activate"));
        activate << qEnvironmentVariable("XDG_ACTIVATION_TOKEN") << page;
        bus.call(activate);
        return 0;
    }

    SettingsStore store(KSharedConfig::openConfig(QStringLiteral("kwinrc")), QStringLiteral(":/main.xml"));
    PresetLibrary presets(&store, QStringLiteral(":/main.xml"), PresetLibrary::defaultDirectory());
    presets.addProvided();

    auto service = new SettingsService(&store);
    bus.registerObject(QStringLiteral("/Settings"), service, QDBusConnection::ExportScriptableSlots);

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    engine.setInitialProperties({{QStringLiteral("store"), QVariant::fromValue<QObject *>(&store)},
                                 {QStringLiteral("presets"), QVariant::fromValue<QObject *>(&presets)},
                                 {QStringLiteral("service"), QVariant::fromValue<QObject *>(service)},
                                 {QStringLiteral("page"), page}});
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    auto window = qobject_cast<QWindow *>(engine.rootObjects().constFirst());
    QObject::connect(service, &SettingsService::activateRequested, window, [window](const QString &token, const QString &page) {
        QMetaObject::invokeMethod(window, "showPage", Q_ARG(QVariant, page));
        if (!token.isEmpty()) {
            KWindowSystem::setCurrentXdgActivationToken(token);
        }
        window->show();
        window->raise();
        KWindowSystem::activateWindow(window);
    });
    return app.exec();
}
