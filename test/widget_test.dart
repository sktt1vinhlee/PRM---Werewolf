import 'package:flutter_test/flutter_test.dart';
import 'package:werewolf/main.dart';

void main() {
  testWidgets('Main menu displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const WerewolfApp());

    expect(find.text('CHƠI'), findsOneWidget);
    expect(find.text('TÚI ĐỒ'), findsOneWidget);
    expect(find.text('CHÀO MỪNG ĐẾN BETA'), findsOneWidget);
  });
}
