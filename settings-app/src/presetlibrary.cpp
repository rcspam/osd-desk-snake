#include "presetlibrary.h"
#include "settingsstore.h"

#include <KConfigGroup>
#include <KConfigLoader>
#include <KLocalizedString>
#include <KSharedConfig>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include <algorithm>

namespace
{
const QString extension = QStringLiteral(".osdsnake");
const QString presetGroup = QStringLiteral("Preset");
const QString settingsGroup = QStringLiteral("Settings");
constexpr int formatVersion = 1;

// File name for a preset name: no folder separator, not hidden.
QString baseNameFor(const QString &name)
{
    QString base = name;
    base.replace(QLatin1Char('/'), QLatin1Char('-'));
    while (base.startsWith(QLatin1Char('.')) || base.startsWith(QLatin1Char(' '))) {
        base.remove(0, 1);
    }
    return base.isEmpty() ? QStringLiteral("preset") : base;
}
}

PresetLibrary::PresetLibrary(SettingsStore *store, const QString &schemaPath, const QString &directory,
                             KSharedConfig::Ptr state, QObject *parent)
    : QObject(parent)
    , m_store(store)
    , m_schemaPath(schemaPath)
    , m_directory(directory)
    , m_state(state ? state : KSharedConfig::openConfig())
{
    m_loaded = m_state->group(QStringLiteral("Presets")).readEntry("Loaded", QString());
    QDir().mkpath(m_directory);
    m_watcher.addPath(m_directory);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &PresetLibrary::reload);
    reload();
    // Every change of a setting ends with a save: the time to check which preset still matches.
    connect(m_store, &SettingsStore::saved, this, &PresetLibrary::updateCurrent);
}

QString PresetLibrary::defaultDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/osdsnake/presets");
}

QStringList PresetLibrary::names() const
{
    QStringList names;
    for (const Preset &preset : m_presets) {
        names.append(preset.name);
    }
    return names;
}

QString PresetLibrary::currentName() const
{
    return m_current;
}

QUrl PresetLibrary::folder() const
{
    return QUrl::fromLocalFile(m_directory);
}

QString PresetLibrary::loadedName() const
{
    return m_loaded;
}

void PresetLibrary::setLoaded(const QString &name)
{
    if (name == m_loaded) {
        return;
    }
    m_loaded = name;
    KConfigGroup group = m_state->group(QStringLiteral("Presets"));
    group.writeEntry("Loaded", name);
    m_state->sync();
    Q_EMIT loadedNameChanged();
}

bool PresetLibrary::contains(const QString &name) const
{
    return indexOf(name) >= 0;
}

QString PresetLibrary::save(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return i18n("The preset needs a name.");
    }
    const QString error = write(pathFor(trimmed), trimmed, m_store->values());
    if (error.isEmpty()) {
        setLoaded(trimmed);
    }
    reload();
    return error;
}

QString PresetLibrary::apply(const QString &name)
{
    const int index = indexOf(name);
    if (index < 0) {
        return i18n("There is no preset called “%1”.", name);
    }
    m_store->replaceAll(m_presets.at(index).values);
    setLoaded(m_presets.at(index).name);
    updateCurrent();
    return {};
}

QString PresetLibrary::rename(const QString &oldName, const QString &newName)
{
    const int index = indexOf(oldName);
    if (index < 0) {
        return i18n("There is no preset called “%1”.", oldName);
    }
    const QString trimmed = newName.trimmed();
    if (trimmed.isEmpty()) {
        return i18n("The preset needs a name.");
    }

    const Preset preset = m_presets.at(index);
    const int taken = indexOf(trimmed);
    // Same preset (only the case changes): keep its file. Taken name: replace that preset.
    const QString target = taken >= 0 ? m_presets.at(taken).path : pathFor(trimmed);
    const QString error = write(target, trimmed, preset.values);
    if (error.isEmpty() && target != preset.path) {
        QFile::remove(preset.path);
    }
    if (error.isEmpty() && m_loaded.compare(preset.name, Qt::CaseInsensitive) == 0) {
        setLoaded(trimmed);
    }
    reload();
    return error;
}

QString PresetLibrary::remove(const QString &name)
{
    const int index = indexOf(name);
    if (index < 0) {
        return i18n("There is no preset called “%1”.", name);
    }
    const QString path = m_presets.at(index).path;
    const bool removed = QFile::remove(path);
    reload();
    return removed ? QString() : i18n("Cannot delete %1.", path);
}

QString PresetLibrary::exportTo(const QString &name, const QUrl &url)
{
    const int index = indexOf(name);
    if (index < 0) {
        return i18n("There is no preset called “%1”.", name);
    }
    QString target = url.toLocalFile();
    if (target.isEmpty()) {
        return i18n("Presets can only be exported to a local file.");
    }
    if (!target.endsWith(extension, Qt::CaseInsensitive)) {
        target += extension;
    }
    const QString source = m_presets.at(index).path;
    if (QFileInfo(target).absoluteFilePath() == source) {
        return {};
    }
    // The file dialog has already asked before replacing an existing file.
    QFile::remove(target);
    return QFile::copy(source, target) ? QString() : i18n("Cannot write %1.", target);
}

QVariantMap PresetLibrary::inspect(const QUrl &url) const
{
    Preset preset;
    const QString error = read(url.toLocalFile(), &preset);
    return {{QStringLiteral("name"), preset.name}, {QStringLiteral("error"), error}};
}

QString PresetLibrary::importFrom(const QUrl &url)
{
    Preset preset;
    QString error = read(url.toLocalFile(), &preset);
    if (error.isEmpty()) {
        // Written again rather than copied: unknown keys go, unreadable values become defaults.
        error = write(pathFor(preset.name), preset.name, preset.values);
        reload();
    }
    return error;
}

QString PresetLibrary::read(const QString &path, Preset *preset) const
{
    const QFileInfo info(path);
    if (path.isEmpty() || !info.isFile() || !info.isReadable()) {
        return i18n("Cannot read %1.", path.isEmpty() ? QStringLiteral("?") : path);
    }
    KSharedConfig::Ptr config = KSharedConfig::openConfig(info.absoluteFilePath(), KConfig::SimpleConfig);
    config->reparseConfiguration();
    if (!config->hasGroup(presetGroup)) {
        return i18n("%1 is not an OSD Desk Snake preset.", info.fileName());
    }

    QFile schema(m_schemaPath);
    KConfigLoader loader(config->group(settingsGroup), &schema);
    preset->values.clear();
    const auto items = loader.items();
    for (const KConfigSkeletonItem *item : items) {
        preset->values.insert(item->key(), item->property());
    }
    preset->name = config->group(presetGroup).readEntry("Name", QString()).trimmed();
    if (preset->name.isEmpty()) {
        preset->name = info.completeBaseName();
    }
    preset->path = info.absoluteFilePath();
    return {};
}

QString PresetLibrary::write(const QString &path, const QString &name, const QVariantMap &values) const
{
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) {
        return i18n("Cannot create the folder %1.", QFileInfo(path).absolutePath());
    }
    KSharedConfig::Ptr config = KSharedConfig::openConfig(path, KConfig::SimpleConfig);
    config->reparseConfiguration();
    config->deleteGroup(settingsGroup);
    KConfigGroup header = config->group(presetGroup);
    header.writeEntry("Name", name);
    header.writeEntry("Version", formatVersion);

    // The loader starts from the defaults (group just deleted) and, like for
    // kwinrc, only writes the values that differ from them.
    QFile schema(m_schemaPath);
    KConfigLoader loader(config->group(settingsGroup), &schema);
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        if (KConfigSkeletonItem *item = loader.findItemByName(it.key())) {
            item->setProperty(it.value());
        }
    }
    const bool saved = loader.save() && config->sync();
    return saved ? QString() : i18n("Cannot write %1.", path);
}

QString PresetLibrary::pathFor(const QString &name) const
{
    const int index = indexOf(name);
    if (index >= 0) {
        return m_presets.at(index).path;
    }
    const QString base = m_directory + QLatin1Char('/') + baseNameFor(name);
    QString path = base + extension;
    for (int n = 2; QFileInfo::exists(path); ++n) {
        path = base + QLatin1Char('-') + QString::number(n) + extension;
    }
    return path;
}

int PresetLibrary::indexOf(const QString &name) const
{
    const QString trimmed = name.trimmed();
    for (int i = 0; i < m_presets.size(); ++i) {
        if (m_presets.at(i).name.compare(trimmed, Qt::CaseInsensitive) == 0) {
            return i;
        }
    }
    return -1;
}

void PresetLibrary::reload()
{
    const QStringList before = names();
    m_presets.clear();
    const QFileInfoList files = QDir(m_directory).entryInfoList({QLatin1Char('*') + extension}, QDir::Files | QDir::Hidden);
    for (const QFileInfo &file : files) {
        Preset preset;
        // Two files with the same name (a copy made by hand): the first one wins.
        if (read(file.absoluteFilePath(), &preset).isEmpty() && indexOf(preset.name) < 0) {
            m_presets.append(preset);
        }
    }
    std::sort(m_presets.begin(), m_presets.end(), [](const Preset &a, const Preset &b) {
        const int order = a.name.compare(b.name, Qt::CaseInsensitive);
        return order != 0 ? order < 0 : a.name < b.name;
    });
    if (names() != before) {
        Q_EMIT namesChanged();
    }
    // The loaded preset was deleted or renamed outside the app.
    if (!m_loaded.isEmpty() && indexOf(m_loaded) < 0) {
        setLoaded(QString());
    }
    updateCurrent();
}

void PresetLibrary::updateCurrent()
{
    const QVariantMap current = m_store->values();
    QString found;
    for (const Preset &preset : std::as_const(m_presets)) {
        if (preset.values == current) {
            found = preset.name;
            break;
        }
    }
    if (found != m_current) {
        m_current = found;
        Q_EMIT currentNameChanged();
    }
}
