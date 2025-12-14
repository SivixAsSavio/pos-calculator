cmake_minimum_required(VERSION 3.14)
project(pos_calculator LANGUAGES CXX)

set(FLUTTER_VERSION "1.0.0+1")
set(FLUTTER_VERSION_MAJOR 1)
set(FLUTTER_VERSION_MINOR 0)
set(FLUTTER_VERSION_PATCH 0)
set(FLUTTER_VERSION_BUILD 1)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED YES)

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

add_subdirectory("flutter")
add_subdirectory("runner")
