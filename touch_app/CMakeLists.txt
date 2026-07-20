if(NOT QtQuick_FOUND)
    message(STATUS "Skipping Touch demo app (Qt Quick not found)")
    return()
endif()

add_executable(vericue-touch-app main.cpp)
target_link_libraries(vericue-touch-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Gui
    Qt::Quick
    Qt::Qml
)
target_compile_definitions(vericue-touch-app PRIVATE
    VERICUE_EXAMPLE_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
