cmake_minimum_required(VERSION 3.16)
project(DomowyPlan VERSION 0.4.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# The kitchen tablet runs a 32-bit Windows 10 installation. Build with the
# matching Qt 5.15.2 x86 kit, even if the development PC is Windows x64.
option(DOMOWYPLAN_REQUIRE_X86 "Reject a 64-bit Windows binary" ON)
if(WIN32 AND DOMOWYPLAN_REQUIRE_X86 AND NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR
        "DomowyPlan EDGE 1086 requires Win32/x86. "
        "Use Qt 5.15.2 mingw81_32 and MinGW 8.1 32-bit (not mingw81_64).")
endif()

find_package(Qt5 5.15.2 EXACT REQUIRED COMPONENTS Core Gui Quick Qml Sql QuickControls2)

add_executable(DomowyPlan WIN32
    src/main.cpp
    src/Backend.cpp
    src/BackendFeatures.cpp
    src/Backend.h
    qml/resources.qrc
)
target_link_libraries(DomowyPlan PRIVATE
    Qt5::Core Qt5::Gui Qt5::Quick Qt5::Qml Qt5::Sql Qt5::QuickControls2
)
if(MSVC)
    target_compile_options(DomowyPlan PRIVATE /W4)
else()
    target_compile_options(DomowyPlan PRIVATE -Wall -Wextra -Wpedantic)
endif()

install(TARGETS DomowyPlan RUNTIME DESTINATION .)

include(CTest)
find_package(Python3 COMPONENTS Interpreter QUIET)
if(BUILD_TESTING AND Python3_Interpreter_FOUND)
    add_test(NAME DomowyPlan_SQLite_and_project_tests
        COMMAND "${Python3_EXECUTABLE}" -m unittest discover -s "${CMAKE_SOURCE_DIR}/tests" -v)
endif()
