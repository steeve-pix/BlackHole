cmake_minimum_required(VERSION 3.25)
project(BlackHole LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find gflw
include(FetchContent)

FetchContent_Declare(
        glfw
        GIT_REPOSITORY https://github.com/glfw/glfw.git
        GIT_TAG 3.4
)

FetchContent_MakeAvailable(glfw)

# GLAD library
add_library(glad STATIC src/glad.c)
target_include_directories(glad PUBLIC include)

# Main exe
file(GLOB_RECURSE SRC_FILES "src/*.cpp")
add_executable(BlackHole ${SRC_FILES})

target_link_libraries(BlackHole PRIVATE glfw glad)

# Copy shaders to build directory
add_custom_command(TARGET BlackHole POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/shaders"
        "$<TARGET_FILE_DIR:BlackHole>/shaders"
        COMMENT "Copying shaders to output directory")