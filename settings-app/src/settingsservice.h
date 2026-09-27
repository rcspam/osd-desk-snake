#pragma once

#include "settingsstore.h"

#include <QObject>
#include <QVariantMap>

// D-Bus entry point (org.kde.osddesksnake.settings, /Settings). The KWin script
// cannot write its own config, so after the indicator is dragged it sends the
// new position here and the app stores it. It also sends the lowest cell sizes
// that still change something (limits), where the form stops its fields.
// A second launch of the app calls activate() on the running one instead of
// opening another window, passing the page its link asked for.
class SettingsService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.osddesksnake.Settings")
    // Setting key -> lowest useful value, e.g. { CellWidth: 79 }. Not exported on D-Bus.
    Q_PROPERTY(QVariantMap limits READ limits NOTIFY limitsChanged)

public:
    explicit SettingsService(SettingsStore *store)
        : QObject(store)
        , m_store(store)
    {
    }

    QVariantMap limits() const
    {
        return m_limits;
    }

public Q_SLOTS:
    Q_SCRIPTABLE void setValues(const QVariantMap &values)
    {
        m_store->setValues(values);
    }

    Q_SCRIPTABLE void setLimits(const QVariantMap &limits)
    {
        if (limits != m_limits) {
            m_limits = limits;
            Q_EMIT limitsChanged();
        }
    }

    // token: the xdg-activation token of the new launch, so KWin lets us take focus.
    // page: the tab asked by its osd-desk-snake:// link ("presets"), or empty.
    Q_SCRIPTABLE void activate(const QString &token, const QString &page)
    {
        Q_EMIT activateRequested(token, page);
    }

Q_SIGNALS:
    void activateRequested(const QString &token, const QString &page);
    void limitsChanged();

private:
    SettingsStore *m_store;
    QVariantMap m_limits;
};
