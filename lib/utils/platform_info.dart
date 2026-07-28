import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// True on Linux / Windows / macOS (not Android / iOS / web).
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

/// True on Android / iOS.
bool get isMobilePlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);
