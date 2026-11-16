import 'package:flutter_test/flutter_test.dart';
import 'package:todo_frontend/main.dart';

void main() {
  testWidgets('app shell renders', (tester) async {
    final store = AppStore(ApiClient());
    await tester.pumpWidget(TodoApp(store: store));
    expect(find.text('Свой день'), findsOneWidget);
  });
}
