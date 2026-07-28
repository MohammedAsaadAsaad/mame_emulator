import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ignore_for_file: non_constant_identifier_names, constant_identifier_names

/// Subset of libretro.h needed to host arcade cores (FBNeo / MAME2003+).

const int RETRO_API_VERSION = 1;

const int RETRO_DEVICE_NONE = 0;
const int RETRO_DEVICE_JOYPAD = 1;

const int RETRO_DEVICE_ID_JOYPAD_B = 0;
const int RETRO_DEVICE_ID_JOYPAD_Y = 1;
const int RETRO_DEVICE_ID_JOYPAD_SELECT = 2;
const int RETRO_DEVICE_ID_JOYPAD_START = 3;
const int RETRO_DEVICE_ID_JOYPAD_UP = 4;
const int RETRO_DEVICE_ID_JOYPAD_DOWN = 5;
const int RETRO_DEVICE_ID_JOYPAD_LEFT = 6;
const int RETRO_DEVICE_ID_JOYPAD_RIGHT = 7;
const int RETRO_DEVICE_ID_JOYPAD_A = 8;
const int RETRO_DEVICE_ID_JOYPAD_X = 9;
const int RETRO_DEVICE_ID_JOYPAD_L = 10;
const int RETRO_DEVICE_ID_JOYPAD_R = 11;
const int RETRO_DEVICE_ID_JOYPAD_L2 = 12;
const int RETRO_DEVICE_ID_JOYPAD_R2 = 13;
const int RETRO_DEVICE_ID_JOYPAD_L3 = 14;
const int RETRO_DEVICE_ID_JOYPAD_R3 = 15;

const int RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10;
const int RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY = 9;
const int RETRO_ENVIRONMENT_SET_MESSAGE = 6;
const int RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME = 18;
const int RETRO_ENVIRONMENT_GET_LOG_INTERFACE = 27;
const int RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY = 31;
const int RETRO_ENVIRONMENT_SET_VARIABLES = 16;
const int RETRO_ENVIRONMENT_GET_VARIABLE = 15;
const int RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE = 17;
const int RETRO_ENVIRONMENT_GET_CAN_DUPE = 3;
const int RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS = 11;
const int RETRO_ENVIRONMENT_GET_INPUT_BITMASKS = 51 | 0x10000; // experimental bit sometimes
const int RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION = 52;
const int RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2 = 67;
const int RETRO_ENVIRONMENT_SET_CORE_OPTIONS = 53;
const int RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL = 54;
const int RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY = 55;
const int RETRO_ENVIRONMENT_GET_LANGUAGE = 39;
const int RETRO_ENVIRONMENT_SET_CONTROLLER_INFO = 35;
const int RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS = 42;
const int RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE = 47;
const int RETRO_ENVIRONMENT_SET_GEOMETRY = 37;
const int RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO = 32;
const int RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL = 8;
const int RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE = 23;
const int RETRO_ENVIRONMENT_GET_FASTFORWARDING = 64;

const int RETRO_PIXEL_FORMAT_0RGB1555 = 0;
const int RETRO_PIXEL_FORMAT_XRGB8888 = 1;
const int RETRO_PIXEL_FORMAT_RGB565 = 2;

const int RETRO_LOG_DEBUG = 0;
const int RETRO_LOG_INFO = 1;
const int RETRO_LOG_WARN = 2;
const int RETRO_LOG_ERROR = 3;

final class RetroSystemInfo extends Struct {
  external Pointer<Utf8> library_name;
  external Pointer<Utf8> library_version;
  external Pointer<Utf8> valid_extensions;
  @Bool()
  external bool need_fullpath;
  @Bool()
  external bool block_extract;
}

final class RetroGameGeometry extends Struct {
  @Uint32()
  external int base_width;
  @Uint32()
  external int base_height;
  @Uint32()
  external int max_width;
  @Uint32()
  external int max_height;
  @Float()
  external double aspect_ratio;
}

final class RetroSystemTiming extends Struct {
  @Double()
  external double fps;
  @Double()
  external double sample_rate;
}

final class RetroSystemAvInfo extends Struct {
  external RetroGameGeometry geometry;
  external RetroSystemTiming timing;
}

final class RetroGameInfo extends Struct {
  external Pointer<Utf8> path;
  external Pointer<Void> data;
  @Size()
  external int size;
  external Pointer<Utf8> meta;
}

final class RetroVariable extends Struct {
  external Pointer<Utf8> key;
  external Pointer<Utf8> value;
}

final class RetroLogCallback extends Struct {
  /// Points at a C `void (*)(int, const char *, ...)` — provided by host_helpers.
  external Pointer<Void> log;
}

final class RetroMessage extends Struct {
  external Pointer<Utf8> msg;
  @Uint32()
  external int frames;
}

typedef RetroEnvironmentNative = Bool Function(Uint32 cmd, Pointer<Void> data);
typedef RetroVideoRefreshNative = Void Function(
  Pointer<Void> data,
  Uint32 width,
  Uint32 height,
  Size pitch,
);
typedef RetroAudioSampleNative = Void Function(Int16 left, Int16 right);
typedef RetroAudioSampleBatchNative = Size Function(Pointer<Int16> data, Size frames);
typedef RetroInputPollNative = Void Function();
typedef RetroInputStateNative = Int16 Function(
  Uint32 port,
  Uint32 device,
  Uint32 index,
  Uint32 id,
);

typedef RetroSetEnvironmentNative = Void Function(
  Pointer<NativeFunction<RetroEnvironmentNative>>,
);
typedef RetroSetVideoRefreshNative = Void Function(
  Pointer<NativeFunction<RetroVideoRefreshNative>>,
);
typedef RetroSetAudioSampleNative = Void Function(
  Pointer<NativeFunction<RetroAudioSampleNative>>,
);
typedef RetroSetAudioSampleBatchNative = Void Function(
  Pointer<NativeFunction<RetroAudioSampleBatchNative>>,
);
typedef RetroSetInputPollNative = Void Function(
  Pointer<NativeFunction<RetroInputPollNative>>,
);
typedef RetroSetInputStateNative = Void Function(
  Pointer<NativeFunction<RetroInputStateNative>>,
);

typedef RetroInitNative = Void Function();
typedef RetroDeinitNative = Void Function();
typedef RetroApiVersionNative = Uint32 Function();
typedef RetroGetSystemInfoNative = Void Function(Pointer<RetroSystemInfo>);
typedef RetroGetSystemAvInfoNative = Void Function(Pointer<RetroSystemAvInfo>);
typedef RetroResetNative = Void Function();
typedef RetroRunNative = Void Function();
typedef RetroSerializeSizeNative = Size Function();
typedef RetroSerializeNative = Bool Function(Pointer<Void> data, Size size);
typedef RetroUnserializeNative = Bool Function(Pointer<Void> data, Size size);
typedef RetroLoadGameNative = Bool Function(Pointer<RetroGameInfo>);
typedef RetroUnloadGameNative = Void Function();

class LibretroBindings {
  LibretroBindings(this.lib)
      : retro_set_environment = lib.lookupFunction<RetroSetEnvironmentNative, void Function(Pointer<NativeFunction<RetroEnvironmentNative>>)>('retro_set_environment'),
        retro_set_video_refresh = lib.lookupFunction<RetroSetVideoRefreshNative, void Function(Pointer<NativeFunction<RetroVideoRefreshNative>>)>('retro_set_video_refresh'),
        retro_set_audio_sample = lib.lookupFunction<RetroSetAudioSampleNative, void Function(Pointer<NativeFunction<RetroAudioSampleNative>>)>('retro_set_audio_sample'),
        retro_set_audio_sample_batch = lib.lookupFunction<RetroSetAudioSampleBatchNative, void Function(Pointer<NativeFunction<RetroAudioSampleBatchNative>>)>('retro_set_audio_sample_batch'),
        retro_set_input_poll = lib.lookupFunction<RetroSetInputPollNative, void Function(Pointer<NativeFunction<RetroInputPollNative>>)>('retro_set_input_poll'),
        retro_set_input_state = lib.lookupFunction<RetroSetInputStateNative, void Function(Pointer<NativeFunction<RetroInputStateNative>>)>('retro_set_input_state'),
        retro_init = lib.lookupFunction<RetroInitNative, void Function()>('retro_init'),
        retro_deinit = lib.lookupFunction<RetroDeinitNative, void Function()>('retro_deinit'),
        retro_api_version = lib.lookupFunction<RetroApiVersionNative, int Function()>('retro_api_version'),
        retro_get_system_info = lib.lookupFunction<RetroGetSystemInfoNative, void Function(Pointer<RetroSystemInfo>)>('retro_get_system_info'),
        retro_get_system_av_info = lib.lookupFunction<RetroGetSystemAvInfoNative, void Function(Pointer<RetroSystemAvInfo>)>('retro_get_system_av_info'),
        retro_reset = lib.lookupFunction<RetroResetNative, void Function()>('retro_reset'),
        retro_run = lib.lookupFunction<RetroRunNative, void Function()>('retro_run'),
        retro_serialize_size = lib.lookupFunction<RetroSerializeSizeNative, int Function()>('retro_serialize_size'),
        retro_serialize = lib.lookupFunction<RetroSerializeNative, bool Function(Pointer<Void>, int)>('retro_serialize'),
        retro_unserialize = lib.lookupFunction<RetroUnserializeNative, bool Function(Pointer<Void>, int)>('retro_unserialize'),
        retro_load_game = lib.lookupFunction<RetroLoadGameNative, bool Function(Pointer<RetroGameInfo>)>('retro_load_game'),
        retro_unload_game = lib.lookupFunction<RetroUnloadGameNative, void Function()>('retro_unload_game');

  final DynamicLibrary lib;

  final void Function(Pointer<NativeFunction<RetroEnvironmentNative>>) retro_set_environment;
  final void Function(Pointer<NativeFunction<RetroVideoRefreshNative>>) retro_set_video_refresh;
  final void Function(Pointer<NativeFunction<RetroAudioSampleNative>>) retro_set_audio_sample;
  final void Function(Pointer<NativeFunction<RetroAudioSampleBatchNative>>) retro_set_audio_sample_batch;
  final void Function(Pointer<NativeFunction<RetroInputPollNative>>) retro_set_input_poll;
  final void Function(Pointer<NativeFunction<RetroInputStateNative>>) retro_set_input_state;
  final void Function() retro_init;
  final void Function() retro_deinit;
  final int Function() retro_api_version;
  final void Function(Pointer<RetroSystemInfo>) retro_get_system_info;
  final void Function(Pointer<RetroSystemAvInfo>) retro_get_system_av_info;
  final void Function() retro_reset;
  final void Function() retro_run;
  final int Function() retro_serialize_size;
  final bool Function(Pointer<Void>, int) retro_serialize;
  final bool Function(Pointer<Void>, int) retro_unserialize;
  final bool Function(Pointer<RetroGameInfo>) retro_load_game;
  final void Function() retro_unload_game;
}
