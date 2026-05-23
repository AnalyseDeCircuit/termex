cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "termex_bridge")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} .. termex_flutter_bridge "")

set(termex_bridge_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
