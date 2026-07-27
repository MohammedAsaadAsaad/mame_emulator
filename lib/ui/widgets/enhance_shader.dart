import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/image_enhancement_mode.dart';

/// GPU fragment shaders for upscaling and CRT effects (from NES emulator).
class EnhanceShader {
  EnhanceShader._();

  static final Map<ImageEnhancementMode, ui.FragmentProgram?> _programs = {};
  static Future<void>? _warmUp;

  static Future<void> warmUp() => _warmUp ??= _loadPrograms();

  static Future<void> _loadPrograms() async {
    final loadedAssets = <String, ui.FragmentProgram?>{};
    for (final mode in ImageEnhancementMode.values) {
      final asset = mode.shaderAsset;
      if (asset == null) continue;
      if (!loadedAssets.containsKey(asset)) {
        try {
          loadedAssets[asset] = await ui.FragmentProgram.fromAsset(asset);
        } on Object {
          loadedAssets[asset] = null;
        }
      }
      _programs[mode] = loadedAssets[asset];
    }
  }

  static bool isReady(ImageEnhancementMode mode) =>
      !mode.usesGpuShader || _programs[mode] != null;

  static ui.FragmentShader? createShader({
    required ImageEnhancementMode mode,
    required ui.Image image,
    required Size outputSize,
  }) {
    final program = _programs[mode];
    if (program == null) return null;

    final shader = program.fragmentShader()
      ..setFloat(0, outputSize.width)
      ..setFloat(1, outputSize.height)
      ..setFloat(2, image.width.toDouble())
      ..setFloat(3, image.height.toDouble());

    if (mode.isCrtVariant) {
      shader.setFloat(4, mode.crtStyle);
    }

    shader.setImageSampler(0, image);
    return shader;
  }
}

class EnhancedFramePainter extends CustomPainter {
  EnhancedFramePainter({
    required this.image,
    required this.outputSize,
    required this.mode,
  });

  final ui.Image image;
  final Size outputSize;
  final ImageEnhancementMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = EnhanceShader.createShader(
      mode: mode,
      image: image,
      outputSize: outputSize,
    );

    if (shader != null) {
      canvas.drawRect(rect, Paint()..shader = shader);
      return;
    }

    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant EnhancedFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.outputSize != outputSize ||
        oldDelegate.mode != mode;
  }
}

/// Integer nearest-neighbor upscale — sharp pixels without GPU shaders.
class IntegerSharpFrame extends StatelessWidget {
  const IntegerSharpFrame({
    required this.image,
    required this.maxWidth,
    required this.maxHeight,
    super.key,
  });

  final ui.Image image;
  final double maxWidth;
  final double maxHeight;

  static int integerScaleFor({
    required double maxW,
    required double maxH,
    required double sourceW,
    required double sourceH,
  }) {
    final scaleX = (maxW / sourceW).floor();
    final scaleY = (maxH / sourceH).floor();
    return (scaleX < scaleY ? scaleX : scaleY).clamp(1, 8);
  }

  @override
  Widget build(BuildContext context) {
    final sourceW = image.width.toDouble();
    final sourceH = image.height.toDouble();
    final scale = integerScaleFor(
      maxW: maxWidth,
      maxH: maxHeight,
      sourceW: sourceW,
      sourceH: sourceH,
    );

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Center(
        child: SizedBox(
          width: sourceW * scale,
          height: sourceH * scale,
          child: RawImage(
            image: image,
            width: sourceW,
            height: sourceH,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
          ),
        ),
      ),
    );
  }
}

/// Fits [source] into [max] while preserving aspect ratio.
Size fitContain(Size source, Size max) {
  if (source.width <= 0 || source.height <= 0) return max;
  final scale = (max.width / source.width < max.height / source.height)
      ? max.width / source.width
      : max.height / source.height;
  return Size(source.width * scale, source.height * scale);
}
