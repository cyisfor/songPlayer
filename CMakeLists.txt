cmake_minimum_required(VERSION 3.14)
project(songpicker)

include(FindPkgConfig)
pkg_check_modules(CRYPT
  REQUIRED IMPORTED_TARGET
  libgcrypt)
pkg_check_modules(DB
  REQUIRED IMPORTED_TARGET
  libpq)
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
#target_link_options(songdb PUBLIC "-Wl,-rpath,${CMAKE_CURRENT_BINARY_DIR}")

add_subdirectory(data_to_header)
function(d2h base)
  data_to_header(gladeFile
  NAME "${base}"
  SOURCE "${base}.glade.xml"
  HEADER "${base}.glade.ch")
endfunction()
d2h(current)
d2h(pause)
d2h(ratebytitle)

add_executable(nowplaying-make
  src/main/nowplaying-make.c)

add_custom_command(
  OUTPUT "nowplaying.fields.ch"
  COMMAND ./nowplaying-make 
  < "${CMAKE_CURRENT_SOURCE_DIR}/nowplaying.fields.conf"
  > "nowplaying.fields.ch"
  MAIN_DEPENDENCY "nowplaying.fields.conf"
  DEPENDS "nowplaying-make")

set(libguess "${CMAKE_CURRENT_SOURCE_DIR}/libguess/")
add_custom_command(
  OUTPUT "${libguess}/src/libguess/libguess.so"
  COMMAND make -j4 libguess.so
  WORKING_DIRECTORY "${libguess}/src/libguess"
  MAIN_DEPENDENCY "${libguess}/buildsys.mk")
add_custom_command(
  OUTPUT "${libguess}/buildsys.mk"
  COMMAND ./configure 
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
  ratebytitle
  replay
  replaygain_scanner)

set(targets
  ${db_targets}
  graph)

foreach(target IN LISTS targets)
  add_executable("${target}"
	"src/main/${target}.c")
endforeach()

install(TARGETS ${targets}
  DESTINATION "${CMAKE_INSTALL_PREFIX}/bin")

add_library(queue
  src/queue.c
  src/adjust.c)
target_link_libraries(queue PUBLIC songdb PkgConfig::GLIB m)
target_compile_options(queue PUBLIC -pthread)
target_link_options(queue PUBLIC -pthread)

add_library(rating
  src/rating.c)
target_link_libraries(rating PUBLIC songdb)

add_library(replaylib
  src/replay.c)
target_link_libraries(replay PUBLIC songdb)

function(linkup)
  cmake_parse_arguments(PARSE_ARGV 0 A "" "" "TARGETS;LIBRARIES")
  foreach(target IN LISTS A_TARGETS A_UNPARSED_ARGUMENTS)
	target_link_libraries("${target}" PRIVATE "${A_LIBRARIES}")
  endforeach()
endfunction(linkup)

linkup(
  TARGETS ${db_targets}
  LIBRARIES songdb)
linkup(
  TARGETS done enqueue enqueuePath mode player replay
  LIBRARIES queue PkgConfig::GLIB)
target_link_libraries(playlist PUBLIC PkgConfig::GLIB)
linkup(
  TARGETS best dscanner player replaygain_scanner
  LIBRARIES PkgConfig::MEDIA)
linkup(
  TARGETS current
  LIBRARIES rating)
linkup(
  TARGETS current pause ratebytitle
  LIBRARIES PkgConfig::GUI)
add_library(synchronize
  src/select.c
  src/synchronize.c)
target_link_libraries(synchronize PUBLIC PkgConfig::GLIB PkgConfig::DB queue)
linkup(
  TARGETS done enqueue enqueuePath mode player replay
  LIBRARIES synchronize)
add_library(get_pid
  src/config.c
  src/get_pid.c)
target_link_libraries(get_pid PUBLIC PkgConfig::DB)

linkup(
  TARGETS next pause player rating
  LIBRARIES get_pid)
add_library(nextreactor
  src/nextreactor.c)
target_link_libraries(nextreactor PUBLIC PkgConfig::DB PkgConfig::UV)
linkup(
  TARGETS nowplaying playlist
  LIBRARIES nextreactor)

install(FILES "${libguess}/src/libguess/libguess.so"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/lib")

foreach(target current pause ratebytitle)
  # ${CMAKE_CURRENT_BINARY_DIR}/ ?
  target_sources("${target}" PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${target}.glade.ch")
  target_include_directories("${target}" PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
endforeach()

target_sources(nowplaying PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/nowplaying.fields.ch")

target_include_directories(nowplaying PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

target_sources(graph PRIVATE src/adjust.c)
target_link_libraries(graph PUBLIC m)

add_library(hash
  src/hash.c)
target_link_libraries(hash PUBLIC PkgConfig::CRYPT)
target_sources(import PRIVATE src/derpstring.c)
target_link_libraries(import PRIVATE "${libguess}/src/libguess/libguess.so" hash)
target_include_directories(import PRIVATE "${libguess}/src/")
target_sources(player PRIVATE src/signals.c)
