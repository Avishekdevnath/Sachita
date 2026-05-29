import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/app.dart';

void main() {
  testWidgets('shows splash while bootstrapping', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SanchitaApp()));

    expect(find.text('Sanchita'), findsOneWidget);
  });
}
