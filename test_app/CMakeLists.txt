add_executable(vericue-test-app main.cpp)
target_link_libraries(vericue-test-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Widgets
)
