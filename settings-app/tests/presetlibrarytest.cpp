#include "presetlibrary.h"
#include "settingsstore.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QColor>
#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <memory>

class PresetLibraryTest : public QObject
{
    Q_OBJECT

private:
    std::unique_ptr<QTemporaryDir> m_dir;
    std::unique_ptr<SettingsStore> m_store;

    QString presetDir() const
    {
        return m_dir->filePath(QStringLiteral("presets"));
    }

    std::unique_ptr<PresetLibrary> library()
    {
        return std::make_unique<PresetLibrary>(m_store.get(), QStringLiteral(DSK_MAIN_XML), presetDir());
    }

    void writeFile(const QString &path, const QByteArray &content)
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(content);
    }

    QUrl url(const QString &fileName) const
    {
        return QUrl::fromLocalFile(m_dir->filePath(fileName));
    }

    int intValue(const char *key) const
    {
        return m_store->value(QString::fromLatin1(key)).toInt();
    }

private Q_SLOTS:
    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        auto config = KSharedConfig::openConfig(m_dir->filePath(QStringLiteral("kwinrc")), KConfig::SimpleConfig);
        m_store = std::make_unique<SettingsStore>(config, QStringLiteral(DSK_MAIN_XML));
        m_store->setSaveDelay(10);
        m_store->setNotifyKWin(false);
    }

    void cleanup()
    {
        m_store.reset();
        m_dir.reset();
    }

    void saveThenApplyRestoresTheValues()
    {
        auto presets = library();
        m_store->setValues({{QStringLiteral("Style"), 2}, {QStringLiteral("ActiveColor"), QColor(160, 0, 200)}});

        QCOMPARE(presets->save(QStringLiteral("Night")), QString());
        QCOMPARE(presets->names(), QStringList{QStringLiteral("Night")});

        m_store->defaults();
        QCOMPARE(intValue("Style"), 0);
        QCOMPARE(presets->apply(QStringLiteral("Night")), QString());
        QCOMPARE(intValue("Style"), 2);
        QCOMPARE(m_store->value(QStringLiteral("ActiveColor")).value<QColor>(), QColor(160, 0, 200));
    }

    void savedFileHoldsOnlyChangedValues()
    {
        auto presets = library();
        m_store->setValues({{QStringLiteral("Style"), 2}});
        QCOMPARE(presets->save(QStringLiteral("Night")), QString());

        KSharedConfig::Ptr file = KSharedConfig::openConfig(presetDir() + QStringLiteral("/Night.osdsnake"), KConfig::SimpleConfig);
        QCOMPARE(file->group(QStringLiteral("Preset")).readEntry("Name"), QStringLiteral("Night"));
        QCOMPARE(file->group(QStringLiteral("Preset")).readEntry("Version", 0), 1);
        QCOMPARE(file->group(QStringLiteral("Settings")).readEntry("Style", 0), 2);
        QVERIFY(!file->group(QStringLiteral("Settings")).hasKey("Anchor"));
    }

    void partialPresetResetsTheOtherKeys()
    {
        writeFile(presetDir() + QStringLiteral("/partial.osdsnake"), "[Preset]\nName=Partial\n\n[Settings]\nStyle=1\n");
        m_store->setValues({{QStringLiteral("Margin"), 200}});
        auto presets = library();

        QCOMPARE(presets->names(), QStringList{QStringLiteral("Partial")});
        QCOMPARE(presets->apply(QStringLiteral("Partial")), QString());
        QCOMPARE(intValue("Style"), 1);
        QCOMPARE(intValue("Margin"), 110);
    }

    void applySavesOnce()
    {
        auto presets = library();
        m_store->setValues({{QStringLiteral("Style"), 2}, {QStringLiteral("Margin"), 5}});
        presets->save(QStringLiteral("Night"));
        QSignalSpy firstSave(m_store.get(), &SettingsStore::saved);
        QVERIFY(firstSave.wait(1000));

        m_store->defaults();
        QVERIFY(firstSave.wait(1000));
        QSignalSpy saved(m_store.get(), &SettingsStore::saved);
        presets->apply(QStringLiteral("Night"));
        QVERIFY(saved.wait(1000));
        QTest::qWait(50);
        QCOMPARE(saved.count(), 1);
    }

    void currentNameFollowsTheSettings()
    {
        auto presets = library();
        QSignalSpy changed(presets.get(), &PresetLibrary::currentNameChanged);
        m_store->setValues({{QStringLiteral("Style"), 2}});
        presets->save(QStringLiteral("Night"));
        QCOMPARE(presets->currentName(), QStringLiteral("Night"));
        QVERIFY(changed.count() >= 1);

        QSignalSpy saved(m_store.get(), &SettingsStore::saved);
        m_store->setValueFromUi(QStringLiteral("Style"), 3);
        QVERIFY(saved.wait(1000));
        QCOMPARE(presets->currentName(), QString());

        presets->apply(QStringLiteral("Night"));
        QCOMPARE(presets->currentName(), QStringLiteral("Night"));
    }

    void emptyNameIsRefused()
    {
        auto presets = library();
        QVERIFY(!presets->save(QStringLiteral("   ")).isEmpty());
        QVERIFY(presets->names().isEmpty());

        presets->save(QStringLiteral("Night"));
        QVERIFY(!presets->rename(QStringLiteral("Night"), QString()).isEmpty());
        QCOMPARE(presets->names(), QStringList{QStringLiteral("Night")});
    }

    void renameAndRemove()
    {
        auto presets = library();
        presets->save(QStringLiteral("Night"));

        QCOMPARE(presets->rename(QStringLiteral("Night"), QStringLiteral("Day")), QString());
        QCOMPARE(presets->names(), QStringList{QStringLiteral("Day")});
        QVERIFY(!QFile::exists(presetDir() + QStringLiteral("/Night.osdsnake")));

        QCOMPARE(presets->remove(QStringLiteral("Day")), QString());
        QVERIFY(presets->names().isEmpty());
        QVERIFY(QDir(presetDir()).entryList(QDir::Files).isEmpty());
    }

    void renameOntoATakenNameReplacesIt()
    {
        auto presets = library();
        m_store->setValues({{QStringLiteral("Style"), 1}});
        presets->save(QStringLiteral("One"));
        m_store->setValues({{QStringLiteral("Style"), 2}});
        presets->save(QStringLiteral("Two"));

        QCOMPARE(presets->rename(QStringLiteral("One"), QStringLiteral("two")), QString());
        QCOMPARE(presets->names(), QStringList{QStringLiteral("two")});
        presets->apply(QStringLiteral("two"));
        QCOMPARE(intValue("Style"), 1);
    }

    void namesIgnoreCase()
    {
        auto presets = library();
        presets->save(QStringLiteral("beta"));
        presets->save(QStringLiteral("Alpha"));
        QCOMPARE(presets->names(), (QStringList{QStringLiteral("Alpha"), QStringLiteral("beta")}));
        QVERIFY(presets->contains(QStringLiteral("ALPHA")));

        // Saving under the same name with another case replaces the preset.
        presets->save(QStringLiteral("ALPHA"));
        QCOMPARE(presets->names(), (QStringList{QStringLiteral("ALPHA"), QStringLiteral("beta")}));
    }

    void awkwardNamesGetTheirOwnFiles()
    {
        auto presets = library();
        presets->save(QStringLiteral("a/b"));
        presets->save(QStringLiteral("a-b"));
        presets->save(QStringLiteral(".hidden"));
        QCOMPARE(presets->names().size(), 3);

        // A new library reads the same presets back from the folder.
        auto again = library();
        QCOMPARE(again->names(), (QStringList{QStringLiteral(".hidden"), QStringLiteral("a-b"), QStringLiteral("a/b")}));
        QCOMPARE(QDir(presetDir()).entryList(QDir::Files).size(), 3);
    }

    void folderIsCreatedAndWatched()
    {
        auto presets = library();
        QVERIFY(QDir(presetDir()).exists());

        // A file dropped into the folder by hand shows up in the list.
        QSignalSpy changed(presets.get(), &PresetLibrary::namesChanged);
        writeFile(presetDir() + QStringLiteral("/dropped.osdsnake"), "[Preset]\nName=Dropped\n");
        QVERIFY(changed.wait(2000));
        QCOMPARE(presets->names(), QStringList{QStringLiteral("Dropped")});
    }

    void sameNameInTwoFilesIsListedOnce()
    {
        writeFile(presetDir() + QStringLiteral("/one.osdsnake"), "[Preset]\nName=Twin\n");
        writeFile(presetDir() + QStringLiteral("/copy of one.osdsnake"), "[Preset]\nName=twin\n");
        auto presets = library();
        QCOMPARE(presets->names().size(), 1);
    }

    void folderIsExposed()
    {
        auto presets = library();
        QCOMPARE(presets->folder(), QUrl::fromLocalFile(presetDir()));
    }

    void exportThenImport()
    {
        auto presets = library();
        m_store->setValues({{QStringLiteral("Style"), 2}});
        presets->save(QStringLiteral("Mine"));

        QCOMPARE(presets->exportTo(QStringLiteral("Mine"), url(QStringLiteral("shared"))), QString());
        QVERIFY(QFile::exists(m_dir->filePath(QStringLiteral("shared.osdsnake"))));
        presets->remove(QStringLiteral("Mine"));
        m_store->defaults();

        const QVariantMap found = presets->inspect(url(QStringLiteral("shared.osdsnake")));
        QCOMPARE(found.value(QStringLiteral("name")).toString(), QStringLiteral("Mine"));
        QCOMPARE(found.value(QStringLiteral("error")).toString(), QString());

        QCOMPARE(presets->importFrom(url(QStringLiteral("shared.osdsnake"))), QString());
        QCOMPARE(presets->names(), QStringList{QStringLiteral("Mine")});
        presets->apply(QStringLiteral("Mine"));
        QCOMPARE(intValue("Style"), 2);
    }

    void exportOntoItsOwnFileKeepsThePreset()
    {
        auto presets = library();
        presets->save(QStringLiteral("Mine"));
        const QUrl own = QUrl::fromLocalFile(presetDir() + QStringLiteral("/Mine.osdsnake"));

        QCOMPARE(presets->exportTo(QStringLiteral("Mine"), own), QString());
        QVERIFY(QFile::exists(own.toLocalFile()));
        QCOMPARE(library()->names(), QStringList{QStringLiteral("Mine")});
    }

    void importRejectsOtherFiles()
    {
        auto presets = library();
        writeFile(m_dir->filePath(QStringLiteral("notes.txt")), "just some text\n");

        QVERIFY(!presets->inspect(url(QStringLiteral("notes.txt"))).value(QStringLiteral("error")).toString().isEmpty());
        QVERIFY(!presets->importFrom(url(QStringLiteral("notes.txt"))).isEmpty());
        QVERIFY(!presets->inspect(url(QStringLiteral("missing.osdsnake"))).value(QStringLiteral("error")).toString().isEmpty());
        QVERIFY(presets->names().isEmpty());
        QVERIFY(!QDir(presetDir()).exists() || QDir(presetDir()).entryList(QDir::Files).isEmpty());
    }

    void importReplacesUnreadableValuesWithDefaults()
    {
        auto presets = library();
        writeFile(m_dir->filePath(QStringLiteral("odd.osdsnake")),
                  "[Preset]\nName=Odd\n\n[Settings]\nMargin=lots\nStyle=2\nNoSuchKey=1\n");

        QCOMPARE(presets->importFrom(url(QStringLiteral("odd.osdsnake"))), QString());
        presets->apply(QStringLiteral("Odd"));
        QCOMPARE(intValue("Margin"), 110);
        QCOMPARE(intValue("Style"), 2);
        QVERIFY(!m_store->contains(QStringLiteral("NoSuchKey")));
    }

    void importWithoutANameUsesTheFileName()
    {
        auto presets = library();
        writeFile(m_dir->filePath(QStringLiteral("Sunny.osdsnake")), "[Preset]\nVersion=1\n\n[Settings]\nStyle=1\n");
        QCOMPARE(presets->inspect(url(QStringLiteral("Sunny.osdsnake"))).value(QStringLiteral("name")).toString(),
                 QStringLiteral("Sunny"));
    }

    void unknownPresetIsAnError()
    {
        auto presets = library();
        QVERIFY(!presets->apply(QStringLiteral("Nope")).isEmpty());
        QVERIFY(!presets->remove(QStringLiteral("Nope")).isEmpty());
        QVERIFY(!presets->rename(QStringLiteral("Nope"), QStringLiteral("Other")).isEmpty());
        QVERIFY(!presets->exportTo(QStringLiteral("Nope"), url(QStringLiteral("x"))).isEmpty());
    }
};

QTEST_GUILESS_MAIN(PresetLibraryTest)
#include "presetlibrarytest.moc"
