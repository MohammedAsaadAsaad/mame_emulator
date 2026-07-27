cmake_minimum_required(VERSION 3.22.1)
project(mame_cabinet_helpers C)

add_library(host_helpers SHARED retro_shim.c)
target_compile_options(host_helpers PRIVATE -O2 -fPIC -Wall)
