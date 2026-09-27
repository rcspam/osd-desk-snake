#include "settingsstore.h"

#include <KConfigLoader>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QFile>

SettingsStore::SettingsStore(KSharedConfig::Ptr config, const QString &schemaPath, QObject *parent)
    : QQmlPropertyMap(this, parent)
    , m_config(std::move(config))
{
    QFile schema(schemaPath);
    m_loader = new KConfigLoader(m_config->group(QStringLiteral("Script-osd-desk-snake")), &schema, this);

    const auto items = m_loader->items();
    for (KConfigSkeletonItem *item : items) {
        insert(item->key(), item->property());
        m_initial.insert(item->key(), item->property());
    }

    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(150);
    connect(&m_saveTimer, &QTimer::timeout, this, &SettingsStore::save);
}

SettingsStore::~SettingsStore()
{
    if (m_saveTimer.isActive()) {
        m_saveTimer.stop();
        save();
    }
}

void SettingsStore::setSaveDelay(int ms)
{
    m_saveTimer.setInterval(ms);
}

void SettingsStore::setNotifyKWin(bool notify)
{
    m_notifyKWin = notify;
}

void SettingsStore::setValueFromUi(const QString &key, const QVariant &value)
{
    if (KConfigSkeletonItem *item = apply(key, value)) {
        insert(key, item->property());
    }
}

QVariant SettingsStore::updateValue(const QString &key, const QVariant &input)
{
    KConfigSkeletonItem *item = apply(key, input);
    return item ? item->property() : value(key);
}

void SettingsStore::setValues(const QVariantMap &values)
{
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        setValueFromUi(it.key(), it.value());
    }
}

void SettingsStore::revert()
{
    setValues(m_initial);
}

void SettingsStore::defaults()
{
    replaceAll({});
}

void SettingsStore::replaceAll(const QVariantMap &values)
{
    QVariantMap all;
    const auto items = m_loader->items();
    for (KConfigSkeletonItem *item : items) {
        const auto given = values.constFind(item->key());
        if (given != values.cend()) {
            all.insert(item->key(), *given);
        } else {
            item->setDefault();
            all.insert(item->key(), item->property());
        }
    }
    setValues(all);
}

QVariantMap SettingsStore::values() const
{
    QVariantMap all;
    const auto items = m_loader->items();
    for (const KConfigSkeletonItem *item : items) {
        all.insert(item->key(), item->property());
    }
    return all;
}

KConfigSkeletonItem *SettingsStore::apply(const QString &key, const QVariant &value)
{
    KConfigSkeletonItem *item = m_loader->findItemByName(key);
    if (item) {
        item->setProperty(value);
        m_saveTimer.start();
    }
    return item;
}

void SettingsStore::save()
{
    m_loader->save();
    if (m_notifyKWin) {
        // KWin caches kwinrc; Scripting.start() re-reads it without restarting running scripts.
        const QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                                                 QStringLiteral("/Scripting"),
                                                                 QStringLiteral("org.kde.kwin.Scripting"),
                                                                 QStringLiteral("start"));
        QDBusConnection::sessionBus().asyncCall(call);
    }
    Q_EMIT saved();
}
