if(NOT QtQuick_FOUND)
    message(STATUS "Skipping QML demo app (Qt Quick not found)")
    return()
endif()

add_executable(vericue-qml-app main.cpp)
target_link_libraries(vericue-qml-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Gui
    Qt::Quick
    Qt::Qml
)
target_compile_definitions(vericue-qml-app PRIVATE
    VERICUE_EXAMPLE_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
