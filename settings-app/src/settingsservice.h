#pragma once

#include "settingsstore.h"

#include <QObject>
#include <QVariantMap>

// D-Bus entry point (org.kde.osddesksnake.settings, /Settings). The KWin script
// cannot write its own config, so after the indicator is dragged it sends the
// new position here and the app stores it. A second launch of the app calls
// activate() on the running one instead of opening another window, passing the
// page its link asked for.
class SettingsService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.osddesksnake.Settings")

public:
    explicit SettingsService(SettingsStore *store)
        : QObject(store)
        , m_store(store)
    {
    }

public Q_SLOTS:
    Q_SCRIPTABLE void setValues(const QVariantMap &values)
    {
        m_store->setValues(values);
    }

    // token: the xdg-activation token of the new launch, so KWin lets us take focus.
    // page: the tab asked by its osd-desk-snake:// link ("presets"), or empty.
    Q_SCRIPTABLE void activate(const QString &token, const QString &page)
    {
        Q_EMIT activateRequested(token, page);
    }

Q_SIGNALS:
    void activateRequested(const QString &token, const QString &page);

private:
    SettingsStore *m_store;
};
