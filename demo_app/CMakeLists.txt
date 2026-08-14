add_executable(vericue-demo-app main.cpp)
target_link_libraries(vericue-demo-app PRIVATE
    ${VERICUE_SERVER_TARGET}
    Qt::Core
    Qt::Widgets
)

# --endpoint (local IPC) is compiled in only when the veriCue being built
# against actually has VeriCueServer::startLocal() - see ../CMakeLists.txt.
if(VERICUE_HAS_LOCAL_IPC)
    target_compile_definitions(vericue-demo-app PRIVATE VERICUE_EXAMPLES_HAS_LOCAL_IPC)
endif()
