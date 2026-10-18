import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sound_marketplace_app/providers/auth_provider.dart';
import 'package:sound_marketplace_app/screens/auth_screen.dart';
import 'package:sound_marketplace_app/services/api_client.dart';
import 'package:sound_marketplace_app/services/user_service.dart';

/// UserService that fails sign-in and accepts password-reset requests, without any network.
class _FakeUserService extends UserService {
  bool forgotCalled = false;

  @override
  Future<AuthSession> login(String email, String password) async =>
      throw ApiException('Invalid email or password', statusCode: 401);

  @override
  Future<void> forgotPassword(String email) async => forgotCalled = true;
}

Widget _wrap(AuthProvider auth) => ChangeNotifierProvider.value(
      value: auth,
      child: const MaterialApp(home: AuthScreen()),
    );

void main() {
  testWidgets('Wrong password shows red error text under the sign-in form', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    final auth = AuthProvider(userService: _FakeUserService());
    await tester.pumpWidget(_wrap(auth));

    await tester.enterText(find.byType(TextFormField).at(0), 'fan@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-the-password');
    await tester.tap(find.text('Log In to Sound Marketplace'));
    await tester.pumpAndSettle();

    final error = find.text('Invalid email or password');
    expect(error, findsOneWidget);
    expect(tester.widget<Text>(error).style?.color, Colors.redAccent);
  });

  testWidgets('Forgot password shows the same message for any email (no account discovery)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    final fake = _FakeUserService();
    await tester.pumpWidget(_wrap(AuthProvider(userService: fake)));

    await tester.tap(find.text('Forgot Password / Username?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Account Email'), 'nobody@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    expect(fake.forgotCalled, isTrue);
    expect(find.textContaining("If an account exists for this email"), findsOneWidget);
    expect(find.textContaining('not found'), findsNothing);
  });
}
