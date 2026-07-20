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

add_subdirectory(demo_app)
add_subdirectory(test_app)
add_subdirectory(qml_app)
add_subdirectory(touch_app)
add_subdirectory(table_app)
add_subdirectory(plain_app)
add_subdirectory(gl_app)
