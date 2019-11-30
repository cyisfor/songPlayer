AC_PREREQ([2.69])
AC_INIT([songplayer], [1.0])
AC_CONFIG_SRCDIR([src/player.c])
AC_CONFIG_MACRO_DIRS([m4])
AC_CONFIG_AUX_DIR([build-aux])
AC_USE_SYSTEM_EXTENSIONS
#AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([foreign subdir-objects])
AM_SILENT_RULES([yes])
LT_INIT([static disable-shared])

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S
PKG_PROG_PKG_CONFIG

# Checks for libraries.
AC_CHECK_LIB([uv], [uv_listen])
AC_CHECK_LIB([m], [log2])

# Checks for header files.
AC_CHECK_HEADERS([arpa/inet.h fcntl.h limits.h malloc.h stddef.h stdint.h stdlib.h string.h sys/time.h unistd.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_CHECK_HEADER_STDBOOL
AC_C_INLINE
AC_TYPE_INT16_T
AC_TYPE_INT32_T
AC_TYPE_INT64_T
AC_TYPE_INT8_T
AC_TYPE_SIZE_T
AC_TYPE_SSIZE_T
AC_TYPE_UINT16_T
AC_TYPE_UINT32_T
AC_TYPE_UINT64_T
AC_TYPE_UINT8_T

# Checks for library functions.
AC_FUNC_ALLOCA
AC_FUNC_ERROR_AT_LINE
AC_FUNC_FORK
AC_FUNC_MALLOC
AC_FUNC_MKTIME
AC_FUNC_MMAP
AC_FUNC_REALLOC
AC_FUNC_STRNLEN
AC_FUNC_STRTOD
AC_CHECK_FUNCS([atexit dup2 gettimeofday memchr memmove memset mkdir realpath select setenv strchr strdup strpbrk strrchr strstr strtol strtoul])

AM_PATH_LIBGCRYPT
PKG_CHECK_MODULES(GUI,[gtk+-3.0])
PKG_CHECK_MODULES(GLIB,[glib-2.0])
PKG_CHECK_MODULES(DB,[libpq])
PKG_CHECK_MODULES(MEDIA,[gstreamer-1.0])
PKG_CHECK_MODULES(UV,[libuv])


AC_CONFIG_FILES([Makefile])
AC_OUTPUT
