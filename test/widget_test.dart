import 'package:flutter_test/flutter_test.dart';
import 'package:open_gmaps/main.dart';

void main() {
  testWidgets('OpenGMaps app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenGMapsApp());
    expect(find.text('Search places, food, hotels'), findsOneWidget);
  });
}
