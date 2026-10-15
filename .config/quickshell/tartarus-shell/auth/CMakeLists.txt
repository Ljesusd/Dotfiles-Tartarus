cmake_minimum_required(VERSION 3.22)
project(tartarus-polkit-agent LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 DBus)
find_package(PolkitQt6-1 REQUIRED)

add_library(auth-controller STATIC AuthController.cpp AuthController.h)
target_link_libraries(auth-controller PUBLIC Qt6::Core)
target_include_directories(auth-controller PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_options(auth-controller PRIVATE -Wall -Wextra -Wpedantic)

qt_add_executable(tartarus-polkit-agent main.cpp PolkitAgent.cpp PolkitAgent.h)
qt_add_resources(tartarus-polkit-agent ui PREFIX "/" FILES Dialog.qml)
target_link_libraries(tartarus-polkit-agent PRIVATE auth-controller
    Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::DBus
    PolkitQt6-1::Core PolkitQt6-1::Agent)
target_compile_options(tartarus-polkit-agent PRIVATE -Wall -Wextra -Wpedantic)
install(TARGETS tartarus-polkit-agent RUNTIME DESTINATION libexec)

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(auth-tests tests.cpp)
    target_link_libraries(auth-tests PRIVATE auth-controller Qt6::Test)
    add_test(NAME auth-state-machine COMMAND auth-tests)
    add_test(NAME auth-qml COMMAND tartarus-polkit-agent --check-ui)
    set_tests_properties(auth-qml PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
endif()
