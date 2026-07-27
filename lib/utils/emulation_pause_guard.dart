import '../emulator/emulator_controller.dart';

/// Pauses emulation while a modal overlay is open (NES EmulationPauseGuard).
abstract final class EmulationPauseGuard {
  static Future<T?> run<T>(
    EmulatorController? controller,
    Future<T?> Function() action,
  ) async {
    if (controller == null || !controller.hasGame) {
      return action();
    }

    final wasRunning = controller.isRunning;
    if (wasRunning) {
      controller.pauseEmulation();
    }

    try {
      return await action();
    } finally {
      if (wasRunning && !controller.isRunning) {
        controller.resumeEmulation();
      }
    }
  }
}
