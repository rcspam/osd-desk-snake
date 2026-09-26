#pragma once

#include <KSharedConfig>

#include <QQmlPropertyMap>
#include <QTimer>
#include <QVariantMap>

class KConfigLoader;
class KConfigSkeletonItem;

// OSD Desk Snake settings as a QML property map, backed by the script's own
// main.xml schema (kwinrc, group [Script-osd-desk-snake]). Every change is saved
// after a short delay, then KWin is asked to re-read kwinrc so the running
// script picks it up.
class SettingsStore : public QQmlPropertyMap
{
    Q_OBJECT

public:
    SettingsStore(KSharedConfig::Ptr config, const QString &schemaPath, QObject *parent = nullptr);
    ~SettingsStore() override;

    void setSaveDelay(int ms);
    void setNotifyKWin(bool notify);

    Q_INVOKABLE void setValueFromUi(const QString &key, const QVariant &value);
    // Several values at once, e.g. the position sent by the KWin script after a drag.
    Q_INVOKABLE void setValues(const QVariantMap &values);
    // Back to the values found when the store was created.
    Q_INVOKABLE void revert();
    // Back to the schema defaults.
    Q_INVOKABLE void defaults();

Q_SIGNALS:
    void saved();

protected:
    QVariant updateValue(const QString &key, const QVariant &input) override;

private:
    // The item for `key` after setting it, or nullptr for an unknown key.
    KConfigSkeletonItem *apply(const QString &key, const QVariant &value);
    void save();

    KSharedConfig::Ptr m_config;
    KConfigLoader *m_loader = nullptr;
    QVariantMap m_initial;
    QTimer m_saveTimer;
    bool m_notifyKWin = true;
};
