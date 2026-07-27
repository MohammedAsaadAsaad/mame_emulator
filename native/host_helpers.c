#include <stdarg.h>
#include <stdio.h>

#if defined(_WIN32)
#define MAME_EXPORT __declspec(dllexport)
#else
#define MAME_EXPORT
#endif

/* Varargs log trampoline for libretro cores (Dart cannot implement this). */
MAME_EXPORT void mame_cabinet_log(int level, const char *fmt, ...) {
  (void)level;
  va_list ap;
  va_start(ap, fmt);
  fputs("[core] ", stderr);
  vfprintf(stderr, fmt, ap);
  va_end(ap);
}
