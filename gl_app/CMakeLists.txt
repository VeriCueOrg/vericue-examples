# QOpenGLWidget lives in Qt6::OpenGLWidgets on Qt 6; on Qt 5 it ships
# inside Qt5::Widgets.
if(QT_VERSION_MAJOR EQUAL 6)
    find_package(Qt6 QUIET COMPONENTS OpenGL OpenGLWidgets)
    if(NOT Qt6OpenGLWidgets_FOUND)
        message(STATUS "Skipping GL demo app (Qt6 OpenGLWidgets not found)")
        return()
    endif()
endif()

set(CMAKE_AUTOMOC ON)

add_executable(vericue-gl-app main.cpp)
target_link_libraries(vericue-gl-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Gui
    Qt::Widgets
)
if(QT_VERSION_MAJOR EQUAL 6)
    target_link_libraries(vericue-gl-app PRIVATE Qt6::OpenGL Qt6::OpenGLWidgets)
endif()
