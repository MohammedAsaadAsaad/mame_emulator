import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'input_mapper.dart';

/// Remappable keyboard bindings (NES-style), persisted in SharedPreferences.
class KeyBindingController {
  static const _prefsKey = 'mame_keyboard_bindings_v1';

  static final Map<ControlAction, LogicalKeyboardKey> defaults = {
    ControlAction.up: LogicalKeyboardKey.arrowUp,
    ControlAction.down: LogicalKeyboardKey.arrowDown,
    ControlAction.left: LogicalKeyboardKey.arrowLeft,
    ControlAction.right: LogicalKeyboardKey.arrowRight,
    ControlAction.a: LogicalKeyboardKey.keyZ,
    ControlAction.b: LogicalKeyboardKey.keyX,
    ControlAction.c: LogicalKeyboardKey.keyC,
    ControlAction.d: LogicalKeyboardKey.keyV,
    ControlAction.coin: LogicalKeyboardKey.digit5,
    ControlAction.start: LogicalKeyboardKey.digit1,
    ControlAction.saveState: LogicalKeyboardKey.f5,
    ControlAction.loadState: LogicalKeyboardKey.f7,
    ControlAction.pause: LogicalKeyboardKey.space,
    ControlAction.reset: LogicalKeyboardKey.f1,
    ControlAction.slotPrev: LogicalKeyboardKey.bracketLeft,
    ControlAction.slotNext: LogicalKeyboardKey.bracketRight,
  };

  Map<ControlAction, LogicalKeyboardKey> bindings = Map.of(defaults);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    bindings = _decode(prefs.getString(_prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(bindings));
  }

  Future<void> setBinding(ControlAction action, LogicalKeyboardKey key) async {
    // Swap if another action already owns this key.
    ControlAction? conflict;
    for (final e in bindings.entries) {
      if (e.key != action && e.value.keyId == key.keyId) {
        conflict = e.key;
        break;
      }
    }
    if (conflict != null) {
      bindings[conflict] = bindings[action]!;
    }
    bindings[action] = key;
    await save();
  }

  Future<void> resetToDefaults() async {
    bindings = Map.of(defaults);
    await save();
  }

  ControlAction? actionForKey(LogicalKeyboardKey key) {
    for (final e in bindings.entries) {
      if (e.value.keyId == key.keyId) return e.key;
    }
    // Aliases that always work (NES-style convenience).
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      return ControlAction.start;
    }
    if (key == LogicalKeyboardKey.escape) return null; // handled as unload host hotkey
    return null;
  }

  static String formatKey(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.isNotEmpty && label.length <= 3) return label.toUpperCase();
    final id = key.debugName ?? key.keyId.toString();
    return id.replaceFirst('Key ', '').replaceFirst('Arrow ', '↑↓←→ '[0]);
  }

  String labelFor(ControlAction action) {
    final key = bindings[action];
    if (key == null) return '—';
    return _pretty(key);
  }

  static String _pretty(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.space) return 'SPACE';
    if (key == LogicalKeyboardKey.bracketLeft) return '[';
    if (key == LogicalKeyboardKey.bracketRight) return ']';
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) return label.toUpperCase();
    return (key.debugName ?? '?').replaceAll('Key ', '').toUpperCase();
  }

  String _encode(Map<ControlAction, LogicalKeyboardKey> map) =>
      map.entries.map((e) => '${e.key.name}:${e.value.keyId}').join(',');

  Map<ControlAction, LogicalKeyboardKey> _decode(String? raw) {
    final merged = Map<ControlAction, LogicalKeyboardKey>.from(defaults);
    if (raw == null || raw.isEmpty) return merged;
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final action = ControlAction.values.where((a) => a.name == kv[0]).firstOrNull;
      final id = int.tryParse(kv[1]);
      if (action == null || id == null) continue;
      merged[action] = LogicalKeyboardKey.findKeyByKeyId(id) ?? merged[action]!;
    }
    return merged;
  }
}
