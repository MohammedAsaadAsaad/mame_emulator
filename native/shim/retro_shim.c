#include <stdarg.h>
#include <stdio.h>

#if defined(_WIN32)
#define MAME_EXPORT __declspec(dllexport)
#else
#define MAME_EXPORT
#endif

/* Varargs logger for libretro GET_LOG_INTERFACE — must be C, not Dart. */
MAME_EXPORT void mame_cabinet_log(int level, const char *fmt, ...) {
  /* 0=debug 1=info 2=warn 3=error — keep console quieter while playing */
  if (level < 2) return;
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
}
