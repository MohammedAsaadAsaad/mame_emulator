#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/stat.h>

struct retro_game_info {
  const char *path;
  const void *data;
  size_t size;
  const char *meta;
};
struct retro_system_info {
  const char *library_name;
  const char *library_version;
  const char *valid_extensions;
  bool need_fullpath;
  bool block_extract;
};
struct retro_log_callback { void (*log)(int, const char *, ...); };

static char system_dir[4096];
static char save_dir[4096];

static void core_log(int level, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  fprintf(stderr, "[core] ");
  vfprintf(stderr, fmt, ap);
  va_end(ap);
}

static bool env_cb(unsigned cmd, void *data) {
  fprintf(stderr, "env cmd=%u data=%p\n", cmd, data);
  switch (cmd) {
    case 10:
      return true;
    case 3:
      if (data) *(bool *)data = true;
      return true;
    case 9:
      if (data) *(const char **)data = system_dir;
      return true;
    case 31:
      if (data) *(const char **)data = save_dir;
      return true;
    case 15:
      if (data) ((struct { const char *k; const char *v; } *)data)->v = NULL;
      return true;
    case 17:
      if (data) *(bool *)data = false;
      return true;
    case 27:
      if (data) ((struct retro_log_callback *)data)->log = core_log;
      return true;
    case 16: case 11: case 35: case 8: case 18: case 42: case 37: case 36: case 6:
    case 53: case 54: case 55: case 67:
      return true;
    case 52:
      if (data) *(unsigned *)data = 1;
      return true;
    case 39:
      if (data) *(unsigned *)data = 0;
      return true;
    default:
      return false;
  }
}

static void video_cb(const void *d, unsigned w, unsigned h, size_t p) { (void)d;(void)w;(void)h;(void)p; }
static void audio_cb(int16_t l, int16_t r) { (void)l;(void)r; }
static size_t audio_batch_cb(const int16_t *d, size_t f) { (void)d; return f; }
static void input_poll_cb(void) {}
static int16_t input_state_cb(unsigned a, unsigned b, unsigned c, unsigned d) { (void)a;(void)b;(void)c;(void)d; return 0; }

int main(int argc, char **argv) {
  if (argc < 3) return 1;
  realpath("native/support", system_dir);
  realpath("native/saves", save_dir);
  mkdir("native/support", 0755);
  mkdir("native/saves", 0755);
  realpath("native/support", system_dir);
  realpath("native/saves", save_dir);
  printf("system=%s\nsave=%s\n", system_dir, save_dir);

  void *h = dlopen(argv[1], RTLD_NOW);
  if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }

  void (*set_env)(void *) = dlsym(h, "retro_set_environment");
  void (*set_video)(void *) = dlsym(h, "retro_set_video_refresh");
  void (*set_audio)(void *) = dlsym(h, "retro_set_audio_sample");
  void (*set_audio_batch)(void *) = dlsym(h, "retro_set_audio_sample_batch");
  void (*set_poll)(void *) = dlsym(h, "retro_set_input_poll");
  void (*set_state)(void *) = dlsym(h, "retro_set_input_state");
  void (*init)(void) = dlsym(h, "retro_init");
  void (*get_info)(struct retro_system_info *) = dlsym(h, "retro_get_system_info");
  bool (*load_game)(const struct retro_game_info *) = dlsym(h, "retro_load_game");
  void (*run)(void) = dlsym(h, "retro_run");
  void (*unload)(void) = dlsym(h, "retro_unload_game");
  void (*deinit)(void) = dlsym(h, "retro_deinit");

  set_env((void*)env_cb);
  set_video((void*)video_cb);
  set_audio((void*)audio_cb);
  set_audio_batch((void*)audio_batch_cb);
  set_poll((void*)input_poll_cb);
  set_state((void*)input_state_cb);
  init();

  struct retro_system_info si; memset(&si, 0, sizeof(si));
  get_info(&si);
  printf("core: %s need_fullpath=%d\n", si.library_name, si.need_fullpath);

  struct retro_game_info gi; memset(&gi, 0, sizeof(gi));
  gi.path = argv[2];
  printf("loading %s\n", gi.path); fflush(stdout);
  bool ok = load_game(&gi);
  printf("load_game => %d\n", ok);
  if (ok) {
    for (int i = 0; i < 5; i++) run();
    printf("frames ok\n");
    unload();
  }
  deinit();
  return ok ? 0 : 2;
}
