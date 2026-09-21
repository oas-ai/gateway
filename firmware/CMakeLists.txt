cmake_minimum_required(VERSION 3.25)
project(oas_gateway_firmware LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(oas_gateway_firmware STATIC src/gateway.c)
target_include_directories(oas_gateway_firmware PUBLIC include)
