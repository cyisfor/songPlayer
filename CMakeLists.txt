cmake_minimum_required(VERSION 3.14)
project(songpicker)

include(FindPkgConfig)
pkg_check_modules(DB
  REQUIRED IMPORTED_TARGET
  pq)
pkg_check_modules(GLIB
  REQUIRED IMPORTED_TARGET
  glib-2.0)
pkg_check_modules(GUI
  IMPORTED_TARGET
  gtk+-3.0)
pkg_check_modules(MEDIA
  IMPORTED_TARGET
  gstreamer-1.0)
pkg_check_modules(UV
  IMPORTED_TARGET
  libuv)

add_library(songdb
  src/pq.c src/preparation.c)
target_link_libraries(songdb PUBLIC PkgConfig::DB)
target_link_flags(songdb PUBLIC "-Wl,-rpath,${CMAKE_CURRENT_BINARY_DIR}")

add_subdirectory(data_to_header)
function(d2h base)
  data_to_header("${base}"
  NAME gladeFile
  SOURCE "${base}.glade.xml"
  HEADER "${base}.glade.ch")
endfunction()
(d2h current)
(d2h pause)
(d2h ratebytitle)

add_executable(nowplaying-make
  src/noplaying-make.c)

add_custom_command(
  OUTPUT "nowplaying.fields.ch"
  COMMAND ./nowplaying-make 
  < "${CMAKE_CURRENT_SOURCE_DIR}/nowplaying.fields.conf"
  > "nowplaying.fields.ch"
  MAIN_DEPENDENCY "nowplaying.fields.ch"
  DEPENDS "nowplaying-make")

set(libguess "${CMAKE_CURRENT_SOURCE_DIR}/libguess/")
add_custom_command(
  OUTPUT "${libguess}/src/libguess/libguess.so"
  COMMAND make -j4 libguess.so
  WORKING_DIRECTORY "${libguess}/src/libguess"
  MAIN_DEPENDENCY "${libguess}/buildsys.mk")
add_custom_command(
  OUTPUT "${libguess}/buildsys.mk"
  COMMAND ./configure --disable-shared
  WORKING_DIRECTORY "${libguess}"
  MAIN_DEPENDENCY "${libguess}/configure")
add_custom_command(
  OUTPUT "${libguess}/configure"
  COMMAND ./autogen.sh
  WORKING_DIRECTORY "${libguess}"
  MAIN_DEPENDENCY "${libguess}/configure.ac")

add_custom_target(libguess
  DEPENDS "${libguess}/src/libguess/libguess.so")

set(db_targets
  addalbum
  best
  current
  done
  dscanner
  enqueue
  enqueuePath
  import
  migrate
  mode
  move_location
  next
  nowplaying
  pause
  player
  playlist
  ratebyalbum
  replay
  replaygain_scanner)


set(targets
  ${db_targets}
  graph)

install(TARGETS ${targets})

foreach(target IN LISTS targets)
  add_executable("${target}"
	"src/${target}.c")
endforeach()

add_library(queue
  src/queue.c
  src/adjust.c)
target_link_libraries(queue PUBLIC songdb)
target_compile_flags(queue PUBLIC -pthread)

target_sources(current PUBLIC current.glade.ch)
function(linkup)
  cmake_parse_arguments(A "" "" "TARGETS;LIBRARIES")
  foreach(target IN LISTS A_TARGETS A_UNPARSED_ARGUMENTS)
	target_link_libraries("${target}" PRIVATE "${A_LIBRARIES}")
  endforeach()
endfunction(linkup)

linkup(
  TARGETS ${db_targets}
  LIBRARIES songdb)
linkup(
  TARGETS done enqueue enqueuePath mode player replay testqueue
  LIBRARIES queue PkgConfig::GLIB)
linkup(
  TARGETS best dscanner player replaygain_scanner
  LIBRARIES PkgConfig::MEDIA)
linkup(
  TARGETS current pause ratebytitle
  LIBRARIES PkgConfig::GUI)
add_library(synchronize
  src/synchronize.c)
linkup(
  TARGETS done enqueue enqueuePath mode player replay
  LIBRARIES synchronize)
add_library(select
  src/select.c)
linkup(
  TARGETS done player
  LIBRARIES select)
add_library(get_pid
  src/config.c
  src/get_pid.c)
linkup(
  TARGETS next pause player
  LIBRARIES get_pid)

install(FILES "${libguess}/src/libguess/libguess.so")

foreach(target current nowplaying pause ratebytitle)
  # ${CMAKE_CURRENT_BINARY_DIR}/ ?
  target_sources("${target}" PRIVATE "${target}.glade.ch")
endforeach()
