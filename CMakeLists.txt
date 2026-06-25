cmake_minimum_required(VERSION 4.2)
project(BlackHole)

set(CMAKE_CXX_STANDARD 23)

file(GLOB_RECURSE SRC_FILES "src/*.cpp")
add_executable(BlackHole ${SRC_FILES})
