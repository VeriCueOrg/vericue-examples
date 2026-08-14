cmake_minimum_required(VERSION 3.16)

# veriCue example applications.
#
# Builds two ways:
#   * Standalone (this repo checked out on its own): compiles against an
#     installed veriCue SDK via find_package(vericue). Point
#     CMAKE_PREFIX_PATH at both your Qt and your veriCue install:
#       cmake -B build -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/opt/vericue"
#   * In-tree (as the examples/ submodule of the main veriCue repository):
#     the parent build already provides Qt aliases and the vericue-server
#     target; this file only adds the app subdirectories.

if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    project(vericue-examples LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 17)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    # Qt detection: prefer Qt6, fall back to Qt5 (mirrors the main repo).
    find_package(Qt6 QUIET COMPONENTS Core Network Widgets)
    if(Qt6_FOUND)
        set(QT_VERSION_MAJOR 6)
        find_package(Qt6 QUIET COMPONENTS Quick Qml)
        message(STATUS "vericue-examples: Using Qt ${Qt6Core_VERSION}")
    else()
        find_package(Qt5 REQUIRED COMPONENTS Core Network Widgets)
        set(QT_VERSION_MAJOR 5)
        find_package(Qt5 QUIET COMPONENTS Quick Qml)
        message(STATUS "vericue-examples: Using Qt ${Qt5Core_VERSION}")
    endif()

    if(QT_VERSION_MAJOR EQUAL 5)
        foreach(_comp Core Gui Network Widgets)
            if(NOT TARGET Qt::${_comp})
                add_library(Qt::${_comp} ALIAS Qt5::${_comp})
            endif()
        endforeach()
        if(Qt5Quick_FOUND AND NOT TARGET Qt::Quick)
            add_library(Qt::Quick ALIAS Qt5::Quick)
            add_library(Qt::Qml ALIAS Qt5::Qml)
        endif()
        set(QtQuick_FOUND ${Qt5Quick_FOUND})
    else()
        set(QtQuick_FOUND ${Qt6Quick_FOUND})
    endif()

    find_package(vericue REQUIRED)
endif()

# The apps link VERICUE_SERVER_TARGET: the in-tree build target when it
# exists, otherwise the imported target from the installed SDK.
if(TARGET vericue-server)
    set(VERICUE_SERVER_TARGET vericue-server)
else()
    set(VERICUE_SERVER_TARGET vericue::vericue-server)
endif()

# --- local IPC availability ---------------------------------------------------
# VeriCueServer::startLocal() (the local IPC transport) arrived in v0.4.0, after
# package on https://dl.vericue.dev. Detect it in the veriCue headers this build
# compiles against, so the repository keeps building against v0.3.5 - there
# demo_app is simply TCP-only and the two local-IPC flows under flows/ are not
# runnable.
set(VERICUE_HAS_LOCAL_IPC OFF)
get_target_property(_vericue_includes ${VERICUE_SERVER_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
if(_vericue_includes)
    foreach(_dir IN LISTS _vericue_includes)
        # In-tree the property holds generator expressions; unwrap the build
        # one and skip anything else that is still a generator expression.
        if(_dir MATCHES "^\\$<BUILD_INTERFACE:(.+)>$")
            set(_dir "${CMAKE_MATCH_1}")
        elseif(_dir MATCHES "^\\$<")
            continue()
        endif()
        if(EXISTS "${_dir}/vericue/server.h")
            file(STRINGS "${_dir}/vericue/server.h" _vericue_start_local REGEX "startLocal")
            if(_vericue_start_local)
                set(VERICUE_HAS_LOCAL_IPC ON)
            endif()
        endif()
    endforeach()
endif()
unset(_vericue_includes)

if(VERICUE_HAS_LOCAL_IPC)
    message(STATUS "vericue-examples: local IPC available - demo_app --endpoint enabled")
else()
    message(STATUS "vericue-examples: this veriCue has no VeriCueServer::startLocal() "
                   "- demo_app is TCP-only (local IPC needs veriCue v0.4.0 or newer)")
endif()

add_subdirectory(demo_app)
add_subdirectory(test_app)
add_subdirectory(qml_app)
add_subdirectory(touch_app)
add_subdirectory(table_app)
add_subdirectory(plain_app)
add_subdirectory(gl_app)
