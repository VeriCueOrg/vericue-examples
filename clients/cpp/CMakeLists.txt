cmake_minimum_required(VERSION 3.16)

# The canonical veriCue scenario as a GoogleTest binary.
#
# A standalone project on purpose: it is what a customer's own test target
# looks like, and building the example applications must not drag GoogleTest
# into everybody's build. Point CMAKE_PREFIX_PATH at your Qt and your veriCue:
#
#   cmake -B build -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/opt/vericue"
#   cmake --build build
#
# GoogleTest is taken from the system when it is installed; otherwise it is
# fetched (needs network on the first configure). Set
# -DVERICUE_SCENARIO_FETCH_GTEST=OFF to require a system GoogleTest instead.

project(vericue-client-scenario-cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(VERICUE_SCENARIO_FETCH_GTEST
       "Download GoogleTest when it is not installed" ON)

find_package(Qt6 QUIET COMPONENTS Core Network)
if(Qt6_FOUND)
    message(STATUS "scenario: using Qt ${Qt6Core_VERSION}")
else()
    find_package(Qt5 REQUIRED COMPONENTS Core Network)
    message(STATUS "scenario: using Qt ${Qt5Core_VERSION}")
    foreach(_comp Core Network)
        if(NOT TARGET Qt::${_comp})
            add_library(Qt::${_comp} ALIAS Qt5::${_comp})
        endif()
    endforeach()
endif()

# vericue::vericue-client - the C++ client library and, with it,
# <vericue/gtest_fixture.h>.
find_package(vericue REQUIRED)

find_package(GTest QUIET)
if(NOT GTest_FOUND)
    if(NOT VERICUE_SCENARIO_FETCH_GTEST)
        message(FATAL_ERROR
                "GoogleTest not found and VERICUE_SCENARIO_FETCH_GTEST=OFF. "
                "Install GoogleTest (e.g. libgtest-dev) or allow the download.")
    endif()
    message(STATUS "scenario: GoogleTest not installed - fetching v1.14.0")
    include(FetchContent)
    FetchContent_Declare(googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.14.0
        GIT_SHALLOW TRUE)
    set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)
endif()

add_executable(vericue-demo-scenario-cpp demo_scenario_test.cpp)
target_link_libraries(vericue-demo-scenario-cpp PRIVATE
    vericue::vericue-client
    Qt::Core
    Qt::Network
    GTest::gtest
    GTest::gtest_main
)

# Optional: `ctest` in this build directory runs the TCP suite. run.sh drives
# the binary directly, because it also starts the application under test.
include(CTest)
if(BUILD_TESTING)
    add_test(NAME demo-scenario
             COMMAND vericue-demo-scenario-cpp --gtest_filter=DemoScenarioTest.*)
endif()
