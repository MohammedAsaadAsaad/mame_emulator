import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mame_cabinet/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('cabinet boots with toolbar and controls', (tester) async {
    await tester.pumpWidget(const MameCabinetApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('COIN'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
    expect(find.text('LOAD'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
