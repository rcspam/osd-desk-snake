cmake_minimum_required(VERSION 3.22)
project(osd-desk-snake-settings LANGUAGES CXX)

# Built on its own by install.sh, or as part of the whole project (../CMakeLists.txt).
if(PROJECT_IS_TOP_LEVEL)
    find_package(ECM 6.0 REQUIRED NO_MODULE)
    set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
    include(KDEInstallDirs)
    include(KDECMakeSettings)
    include(KDECompilerSettings NO_POLICY_SCOPE)
endif()
include(ECMAddTests)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus Test)
find_package(KF6 REQUIRED COMPONENTS Config I18n WindowSystem)

# Single source of truth for the settings: the KWin script's own schema.
set(DSK_SCHEMA ${CMAKE_CURRENT_SOURCE_DIR}/../package/contents/config/main.xml)

add_library(settingsstore STATIC src/settingsstore.cpp src/settingsservice.h src/presetlibrary.cpp)
target_include_directories(settingsstore PUBLIC src)
target_link_libraries(settingsstore PUBLIC Qt6::Qml Qt6::DBus KF6::ConfigCore KF6::ConfigGui KF6::I18n)
target_compile_definitions(settingsstore PRIVATE TRANSLATION_DOMAIN="osd-desk-snake")

add_executable(osd-desk-snake-settings src/main.cpp)
target_link_libraries(osd-desk-snake-settings PRIVATE settingsstore Qt6::Widgets Qt6::Quick Qt6::QuickControls2 KF6::I18n KF6::I18nQml KF6::WindowSystem)

set_source_files_properties(${DSK_SCHEMA} PROPERTIES QT_RESOURCE_ALIAS main.xml)
qt_add_resources(osd-desk-snake-settings schema PREFIX / FILES ${DSK_SCHEMA})
qt_add_resources(osd-desk-snake-settings qml PREFIX / BASE src/qml FILES
    src/qml/Main.qml
    src/qml/FieldEditor.qml
    src/qml/ColorButton.qml
    src/qml/PresetsPage.qml
    src/qml/fields.js
    src/qml/wheel.js
)

install(TARGETS osd-desk-snake-settings ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})

if(BUILD_TESTING)
    ecm_add_test(tests/settingsstoretest.cpp LINK_LIBRARIES settingsstore Qt6::Test TEST_NAME settingsstoretest)
    target_compile_definitions(settingsstoretest PRIVATE DSK_MAIN_XML="${DSK_SCHEMA}")
    ecm_add_test(tests/presetlibrarytest.cpp LINK_LIBRARIES settingsstore Qt6::Test TEST_NAME presetlibrarytest)
    target_compile_definitions(presetlibrarytest PRIVATE DSK_MAIN_XML="${DSK_SCHEMA}")
endif()
