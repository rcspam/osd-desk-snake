# Whole project, installed system-wide: used by the .deb, .rpm and PKGBUILD.
# (install.sh installs for the current user instead, without this file.)
cmake_minimum_required(VERSION 3.22)
project(osd-desk-snake VERSION 0.2.1 LANGUAGES CXX)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(ID osd-desk-snake)
option(INSTALL_DEBIAN_DOCS "Install the Debian copyright and changelog files (for the .deb)" OFF)

# Packages want 0755 directories whatever the umask of the build machine.
set(CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

add_subdirectory(settings-app)

# KWin script: KWin looks for scripts in <data dir>/kwin/scripts.
install(DIRECTORY package/ DESTINATION ${KDE_INSTALL_DATADIR}/kwin/scripts/${ID}
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
        PATTERN locale EXCLUDE)

# Presets shipped with the settings app, copied into the user's preset folder
# (~/.config/osdsnake/presets) the first time the app sees them.
install(DIRECTORY presets/ DESTINATION ${KDE_INSTALL_DATADIR}/${ID}/presets
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)

# Translations, shared by the script settings page and the app (domain osd-desk-snake).
find_program(MSGFMT msgfmt REQUIRED)
file(GLOB PO_FILES ${CMAKE_CURRENT_SOURCE_DIR}/po/*.po)
set(MO_FILES)
foreach(po ${PO_FILES})
    get_filename_component(lang ${po} NAME_WE)
    set(mo ${CMAKE_CURRENT_BINARY_DIR}/locale/${lang}/${ID}.mo)
    add_custom_command(OUTPUT ${mo}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/locale/${lang}
        COMMAND ${MSGFMT} -o ${mo} ${po}
        DEPENDS ${po})
    list(APPEND MO_FILES ${mo})
    install(FILES ${mo} DESTINATION ${KDE_INSTALL_LOCALEDIR}/${lang}/LC_MESSAGES)
endforeach()
add_custom_target(translations ALL DEPENDS ${MO_FILES})

# Launcher of the settings app, also the handler of the osd-desk-snake:// link.
set(BINARY ${ID}-settings)
configure_file(settings-app/${ID}-settings.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/${ID}-settings.desktop @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${ID}-settings.desktop DESTINATION ${KDE_INSTALL_APPDIR})

# Manual page, compressed as all three distributions expect.
find_program(GZIP gzip REQUIRED)
set(MAN_GZ ${CMAKE_CURRENT_BINARY_DIR}/${ID}-settings.1.gz)
add_custom_command(OUTPUT ${MAN_GZ}
    COMMAND ${GZIP} -9nc ${CMAKE_CURRENT_SOURCE_DIR}/packaging/man/${ID}-settings.1 > ${MAN_GZ}
    DEPENDS packaging/man/${ID}-settings.1)
add_custom_target(manpage ALL DEPENDS ${MAN_GZ})
install(FILES ${MAN_GZ} DESTINATION ${KDE_INSTALL_MANDIR}/man1)

if(INSTALL_DEBIAN_DOCS)
    set(CHANGELOG_GZ ${CMAKE_CURRENT_BINARY_DIR}/changelog.gz)
    add_custom_command(OUTPUT ${CHANGELOG_GZ}
        COMMAND ${GZIP} -9nc ${CMAKE_CURRENT_SOURCE_DIR}/packaging/debian/changelog > ${CHANGELOG_GZ}
        DEPENDS packaging/debian/changelog)
    add_custom_target(debian_changelog ALL DEPENDS ${CHANGELOG_GZ})
    install(FILES packaging/debian/copyright ${CHANGELOG_GZ} DESTINATION ${KDE_INSTALL_DATAROOTDIR}/doc/${ID})
endif()

# Debian package: cpack -G DEB (libraries found by dpkg-shlibdeps, QML modules listed here).
set(CPACK_PACKAGE_NAME ${ID})
set(CPACK_PACKAGE_VENDOR "rcspam")
set(CPACK_PACKAGE_CONTACT "rcspam <10021906+rcspam@users.noreply.github.com>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Kara-style on-screen indicator for KDE Plasma 6 virtual desktop switches")
set(CPACK_PACKAGE_DESCRIPTION "KWin script showing an indicator when switching virtual desktops:
pills, labels, icons or open windows, at a configurable position. The
highlight follows the desktop switch animation and touchpad swipes.
Includes a live settings app.")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/rcspam/osd-desk-snake")
set(CPACK_RESOURCE_FILE_LICENSE ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE)
set(CPACK_PACKAGING_INSTALL_PREFIX /usr)
set(CPACK_STRIP_FILES ON)
set(CPACK_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS ${CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS})
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_SECTION kde)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "kwin-wayland | kwin-x11, qml6-module-org-kde-kirigami, qml6-module-org-kde-ksvg, qml6-module-org-kde-desktop, qml6-module-qtquick-controls, qml6-module-qtquick-dialogs, qml6-module-qtquick-layouts, qml6-module-qtqml-models, qml6-module-qtcore")
include(CPack)
