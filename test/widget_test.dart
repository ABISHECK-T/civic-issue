import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_issue_reporting/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:citizen_issue_reporting/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows Home Page', (WidgetTester tester) async {
    // Initialize Firebase for widget tests to avoid `No Firebase App` errors
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // HomePage headers/buttons
    expect(find.text('Citizen Issue Reporting System'), findsOneWidget);
    expect(find.text('Citizen Login'), findsOneWidget);
    expect(find.text('Government Login'), findsOneWidget);
  });
}
