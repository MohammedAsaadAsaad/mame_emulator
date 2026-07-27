/// GPU / nearest-neighbor display modes (ported from NES emulator).
enum ImageEnhancementMode {
  xbrz('xbrz'),
  hqx('hqx'),
  integerSharp('integer_sharp'),
  crtClassic('crt'),
  crtArcade('crt_arcade'),
  crtNtsc('crt_ntsc'),
  crtLight('crt_light'),
  crtPvm('crt_pvm'),
  crtSmooth('crt_smooth');

  const ImageEnhancementMode(this.id);

  final String id;

  static ImageEnhancementMode? fromId(String? id) {
    if (id == null) return null;
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return null;
  }

  bool get usesGpuShader => this != integerSharp;

  bool get isCrtVariant => switch (this) {
        crtClassic ||
        crtArcade ||
        crtNtsc ||
        crtLight ||
        crtPvm ||
        crtSmooth =>
          true,
        _ => false,
      };

  double get crtStyle => switch (this) {
        crtClassic => 0.0,
        crtArcade => 1.0,
        crtNtsc => 2.0,
        crtLight => 3.0,
        crtPvm => 4.0,
        crtSmooth => 5.0,
        _ => 0.0,
      };

  String? get shaderAsset => switch (this) {
        xbrz => 'shaders/nes_enhance.frag',
        hqx => 'shaders/nes_hqx.frag',
        integerSharp => null,
        _ when isCrtVariant => 'shaders/nes_crt.frag',
        _ => null,
      };

  String get label => switch (this) {
        xbrz => 'xBRZ',
        hqx => 'HQx',
        integerSharp => 'Integer sharp',
        crtClassic => 'CRT classic',
        crtArcade => 'CRT arcade',
        crtNtsc => 'NTSC',
        crtLight => 'CRT subtle',
        crtPvm => 'PVM / Trinitron',
        crtSmooth => 'CRT + smooth',
      };

  String get shortLabel => switch (this) {
        xbrz => 'xBRZ',
        hqx => 'HQx',
        integerSharp => '1×',
        crtClassic => 'CRT',
        crtArcade => 'ARC',
        crtNtsc => 'NTSC',
        crtLight => 'LITE',
        crtPvm => 'PVM',
        crtSmooth => 'SMTH',
      };
}
