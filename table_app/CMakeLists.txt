add_executable(vericue-table-app main.cpp)
target_link_libraries(vericue-table-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Widgets
)
