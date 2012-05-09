cmake_minimum_required(VERSION 2.8)

include(FindPkgConfig)
include(FindPostgreSQL)

if (!POSTGRESQL_FOUND)
   message(FATAL_ERROR need libpq)
endif()

pkg_check_modules(GSTREAMER REQUIRED gstreamer-0.10)

include_directories(${PostgreSQL_INCLUDE_DIRS};${GSTREAMER_INCLUDE_DIRS})

add_executable(player player.c urlcodec.c config.c)
add_executable(select select.c config.c pq.c)
add_executable(queue queue.c config.c pq.c)
add_executable(restitch restitch.c pq.c)
add_executable(scanner scan.c urlcodec.c)
add_executable(dscanner durationscan.c urlcodec.c)
add_executable(migrate versioning.c pq.c)

target_link_libraries(player ${LIBS};${GSTREAMER_LIBRARIES})
target_link_libraries(select ${LIBS};${PostgreSQL_LIBRARIES})
target_link_libraries(queue ${LIBS};${PostgreSQL_LIBRARIES};m)
target_link_libraries(migrate ${LIBS};${PostgreSQL_LIBRARIES})
target_link_libraries(restitch ${LIBS};${PostgreSQL_LIBRARIES})

target_link_libraries(scanner ${LIBS};${GSTREAMER_LIBRARIES})
target_link_libraries(dscanner ${LIBS};${GSTREAMER_LIBRARIES})
	
