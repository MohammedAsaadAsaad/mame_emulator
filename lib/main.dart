import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/arcade_cabinet_page.dart';
import 'ui/widgets/enhance_shader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await EnhanceShader.warmUp();

  try {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(420, 780),
      minimumSize: Size(360, 420),
      center: true,
      backgroundColor: Colors.black,
      skipTaskbar: false,
      title: 'MAME Emulator',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (_) {
    // Mobile / platforms without window_manager — continue.
  }

  runApp(const MameCabinetApp());
}

class MameCabinetApp extends StatelessWidget {
  const MameCabinetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAME Emulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      ),
      home: const ArcadeCabinetPage(),
    );
  }
}
