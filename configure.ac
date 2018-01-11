#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([songpicker], [1.0], [nah])
AM_INIT_AUTOMAKE

AC_USE_SYSTEM_EXTENSIONS

LT_INIT

AC_CONFIG_SRCDIR([src/])
AC_CONFIG_HEADERS([site-config.h])


AC_USE_SYSTEM_EXTENSIONS

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S

# Checks for libraries.

PKG_PROG_PKG_CONFIG
PKG_CHECK_MODULES(PQ, libpq)
PKG_CHECK_MODULES(GSTREAMER, gstreamer-1.0)
PKG_CHECK_MODULES(GLIB, glib-2.0)

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
AC_FUNC_REALLOC
AC_FUNC_STRNLEN
AC_FUNC_STRTOD
AC_CHECK_FUNCS([atexit dup2 gettimeofday memchr memmove memset mkdir realpath select setenv strchr strdup strrchr strstr strtol strtoul])

AC_CONFIG_FILES([Makefile
src/Makefile])

AC_OUTPUT
