#include <stdarg.h>
#include <stdio.h>

/* Varargs log trampoline for libretro cores (Dart cannot implement this). */
void mame_cabinet_log(int level, const char *fmt, ...) {
  (void)level;
  va_list ap;
  va_start(ap, fmt);
  fputs("[core] ", stderr);
  vfprintf(stderr, fmt, ap);
  va_end(ap);
}
