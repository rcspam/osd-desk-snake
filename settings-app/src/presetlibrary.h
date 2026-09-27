#pragma once

#include <QFileSystemWatcher>
#include <QList>
#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>

class SettingsStore;

// Named sets of settings, one KConfig file per preset (<name>.osdsnake) in a
// folder: [Preset] holds the name, [Settings] the same keys as kwinrc, read and
// written through the script schema so only non-default values are stored.
// The folder is watched, so presets copied into it by hand show up at once.
// Actions return an error message for the user, empty on success.
class PresetLibrary : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList names READ names NOTIFY namesChanged)
    // The preset equal to the current settings, empty if none is.
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentNameChanged)

public:
    PresetLibrary(SettingsStore *store, const QString &schemaPath, const QString &directory, QObject *parent = nullptr);

    // ~/.config/osdsnake/presets
    static QString defaultDirectory();

    QStringList names() const;
    QString currentName() const;

    Q_INVOKABLE bool contains(const QString &name) const;
    // Saves the current settings, replacing a preset of the same name.
    Q_INVOKABLE QString save(const QString &name);
    Q_INVOKABLE QString apply(const QString &name);
    // Replaces a preset already called newName.
    Q_INVOKABLE QString rename(const QString &oldName, const QString &newName);
    Q_INVOKABLE QString remove(const QString &name);
    // Adds the .osdsnake extension when the file name has none.
    Q_INVOKABLE QString exportTo(const QString &name, const QUrl &url);
    // Reads a file to import without copying it: { name, error }.
    Q_INVOKABLE QVariantMap inspect(const QUrl &url) const;
    // Replaces a preset of the same name.
    Q_INVOKABLE QString importFrom(const QUrl &url);

Q_SIGNALS:
    void namesChanged();
    void currentNameChanged();

private:
    struct Preset {
        QString name;
        QString path;
        QVariantMap values; // every key, defaults included
    };

    // Name and values of a preset file, or an error.
    QString read(const QString &path, Preset *preset) const;
    QString write(const QString &path, const QString &name, const QVariantMap &values) const;
    // Existing preset or a new free file for this name.
    QString pathFor(const QString &name) const;
    int indexOf(const QString &name) const;
    void reload();
    void updateCurrent();

    SettingsStore *m_store;
    QString m_schemaPath;
    QString m_directory;
    QList<Preset> m_presets;
    QString m_current;
    QFileSystemWatcher m_watcher;
};
