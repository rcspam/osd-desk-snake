#include "settingsservice.h"
#include "settingsstore.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QColor>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class SettingsStoreTest : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    KSharedConfig::Ptr freshConfig(const QString &name)
    {
        return KSharedConfig::openConfig(m_dir.filePath(name), KConfig::SimpleConfig);
    }

    // What another process (KWin) would read from the file.
    static KConfigGroup onDisk(const KSharedConfig::Ptr &config)
    {
        KSharedConfig::Ptr reread = KSharedConfig::openConfig(config->name(), KConfig::SimpleConfig);
        reread->reparseConfiguration();
        return reread->group(QStringLiteral("Script-osd-desk-snake"));
    }

private Q_SLOTS:
    void loadsDefaultsAndStoredValues()
    {
        auto config = freshConfig(QStringLiteral("load"));
        config->group(QStringLiteral("Script-osd-desk-snake")).writeEntry("DisplayDuration", 3000);
        config->sync();

        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        QCOMPARE(store.value(QStringLiteral("DisplayDuration")).toInt(), 3000);
        QCOMPARE(store.value(QStringLiteral("Anchor")).toInt(), 7);
        QCOMPARE(store.value(QStringLiteral("LabelTemplate")).toString(), QStringLiteral("D%d"));
        QCOMPARE(store.value(QStringLiteral("ActiveColor")).value<QColor>(), QColor(61, 174, 233));
    }

    void savesChangesAfterADelay()
    {
        auto config = freshConfig(QStringLiteral("save"));
        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setSaveDelay(10);
        store.setNotifyKWin(false);
        QSignalSpy saved(&store, &SettingsStore::saved);

        store.setValueFromUi(QStringLiteral("PillShape"), 3);
        store.setValueFromUi(QStringLiteral("ActiveColor"), QColor(255, 0, 0, 128));

        QVERIFY(saved.wait(1000));
        QCOMPARE(saved.count(), 1);
        QCOMPARE(onDisk(config).readEntry("PillShape", 0), 3);
        QCOMPARE(onDisk(config).readEntry("ActiveColor", QColor()), QColor(255, 0, 0, 128));
        QCOMPARE(store.value(QStringLiteral("PillShape")).toInt(), 3);
    }

    void defaultValuesAreNotWritten()
    {
        auto config = freshConfig(QStringLiteral("defaults-not-written"));
        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setSaveDelay(10);
        store.setNotifyKWin(false);
        QSignalSpy saved(&store, &SettingsStore::saved);

        store.setValueFromUi(QStringLiteral("Anchor"), 7);
        QVERIFY(saved.wait(1000));
        QVERIFY(!onDisk(config).hasKey("Anchor"));
    }

    void revertRestoresValuesFromOpening()
    {
        auto config = freshConfig(QStringLiteral("revert"));
        config->group(QStringLiteral("Script-osd-desk-snake")).writeEntry("Margin", 200);
        config->sync();

        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setSaveDelay(10);
        store.setNotifyKWin(false);
        QSignalSpy saved(&store, &SettingsStore::saved);
        store.setValueFromUi(QStringLiteral("Margin"), 5);
        QVERIFY(saved.wait(1000));

        store.revert();
        QVERIFY(saved.wait(1000));
        QCOMPARE(store.value(QStringLiteral("Margin")).toInt(), 200);
        QCOMPARE(onDisk(config).readEntry("Margin", 0), 200);
    }

    void defaultsResetEverything()
    {
        auto config = freshConfig(QStringLiteral("reset"));
        config->group(QStringLiteral("Script-osd-desk-snake")).writeEntry("Margin", 200);
        config->group(QStringLiteral("Script-osd-desk-snake")).writeEntry("Style", 2);
        config->sync();

        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setSaveDelay(10);
        store.setNotifyKWin(false);
        QSignalSpy saved(&store, &SettingsStore::saved);
        store.defaults();

        QVERIFY(saved.wait(1000));
        QCOMPARE(store.value(QStringLiteral("Margin")).toInt(), 110);
        QCOMPARE(store.value(QStringLiteral("Style")).toInt(), 0);
        QVERIFY(!onDisk(config).hasKey("Margin"));
        QVERIFY(!onDisk(config).hasKey("Style"));
    }

    void replaceAllSetsGivenKeysAndResetsTheRest()
    {
        auto config = freshConfig(QStringLiteral("replace-all"));
        config->group(QStringLiteral("Script-osd-desk-snake")).writeEntry("Margin", 200);
        config->sync();

        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setSaveDelay(10);
        store.setNotifyKWin(false);
        QSignalSpy saved(&store, &SettingsStore::saved);
        store.replaceAll({{QStringLiteral("Style"), 2}, {QStringLiteral("NoSuchKey"), 1}});

        QVERIFY(saved.wait(1000));
        QCOMPARE(saved.count(), 1);
        QCOMPARE(store.value(QStringLiteral("Style")).toInt(), 2);
        QCOMPARE(store.value(QStringLiteral("Margin")).toInt(), 110);
        QCOMPARE(onDisk(config).readEntry("Style", 0), 2);
        QVERIFY(!onDisk(config).hasKey("Margin"));
    }

    void valuesListsEveryKey()
    {
        auto config = freshConfig(QStringLiteral("values"));
        config->group(QStringLiteral("Script-osd-desk-snake")).writeEntry("Margin", 200);
        config->sync();

        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        const QVariantMap values = store.values();
        QCOMPARE(values.size(), store.keys().size());
        QCOMPARE(values.value(QStringLiteral("Margin")).toInt(), 200);
        QCOMPARE(values.value(QStringLiteral("Anchor")).toInt(), 7);
    }

    void setValuesAppliesSeveralAtOnce()
    {
        auto config = freshConfig(QStringLiteral("set-values"));
        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setSaveDelay(10);
        store.setNotifyKWin(false);
        QSignalSpy saved(&store, &SettingsStore::saved);

        // As sent by the KWin script over D-Bus: JS numbers arrive as doubles.
        store.setValues({{QStringLiteral("Anchor"), 8.0},
                         {QStringLiteral("OffsetX"), -12.0},
                         {QStringLiteral("PercentX"), 60.1},
                         {QStringLiteral("NoSuchKey"), 1}});

        QVERIFY(saved.wait(1000));
        QCOMPARE(saved.count(), 1);
        QCOMPARE(store.value(QStringLiteral("Anchor")).toInt(), 8);
        QCOMPARE(onDisk(config).readEntry("OffsetX", 0), -12);
        QCOMPARE(onDisk(config).readEntry("PercentX", 0.0), 60.1);
    }

    void qmlBindingsFollowChangesFromCpp()
    {
        auto config = freshConfig(QStringLiteral("qml-binding"));
        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setNotifyKWin(false);

        QQmlEngine engine;
        QQmlComponent component(&engine);
        // Same lookup as FieldEditor.qml: a key held in a property.
        component.setData("import QtQml\nQtObject { required property var store; property string key: \"Anchor\"; "
                          "readonly property var value: store[key] }",
                          QUrl());
        std::unique_ptr<QObject> object(component.createWithInitialProperties({{QStringLiteral("store"), QVariant::fromValue<QObject *>(&store)}}));
        QVERIFY2(object, qPrintable(component.errorString()));
        QCOMPARE(object->property("value").toInt(), 7);

        store.setValues({{QStringLiteral("Anchor"), 0.0}});
        QCOMPARE(object->property("value").toInt(), 0);

        store.defaults();
        QCOMPARE(object->property("value").toInt(), 7);
    }

    void serviceKeepsTheLimitsFromTheScript()
    {
        auto config = freshConfig(QStringLiteral("limits"));
        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        auto service = new SettingsService(&store);
        QSignalSpy changed(service, &SettingsService::limitsChanged);

        // As sent by the KWin script over D-Bus: JS numbers arrive as doubles.
        service->setLimits({{QStringLiteral("CellWidth"), 79.0}, {QStringLiteral("CellHeight"), 79.0}});
        QCOMPARE(changed.count(), 1);
        QCOMPARE(service->limits().value(QStringLiteral("CellWidth")).toInt(), 79);

        // The script sends them again after each change of its content: no signal if equal.
        service->setLimits({{QStringLiteral("CellWidth"), 79.0}, {QStringLiteral("CellHeight"), 79.0}});
        QCOMPARE(changed.count(), 1);
    }

    void unknownKeysAreIgnored()
    {
        auto config = freshConfig(QStringLiteral("unknown"));
        SettingsStore store(config, QStringLiteral(DSK_MAIN_XML));
        store.setValueFromUi(QStringLiteral("NoSuchKey"), 1);
        QVERIFY(!store.contains(QStringLiteral("NoSuchKey")));
    }
};

QTEST_GUILESS_MAIN(SettingsStoreTest)
#include "settingsstoretest.moc"
