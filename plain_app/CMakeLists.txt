# Deliberately NOT linked against vericue-server - this is the injection victim.
add_executable(vericue-plain-app main.cpp)
target_link_libraries(vericue-plain-app PRIVATE
    Qt::Core
    Qt::Widgets
)
