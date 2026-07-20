add_executable(vericue-demo-app main.cpp)
target_link_libraries(vericue-demo-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Widgets
)
