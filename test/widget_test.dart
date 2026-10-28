import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sound_marketplace_app/models/user_account.dart';
import 'package:sound_marketplace_app/providers/auth_provider.dart';
import 'package:sound_marketplace_app/providers/cart_provider.dart';
import 'package:sound_marketplace_app/providers/marketplace_provider.dart';
import 'package:sound_marketplace_app/screens/admin_moderation_screen.dart';
import 'package:sound_marketplace_app/screens/auth_screen.dart';
import 'package:sound_marketplace_app/screens/checkout_screen.dart';
import 'package:sound_marketplace_app/screens/library_screen.dart';
import 'package:sound_marketplace_app/screens/profile_screen.dart';
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

Widget _wrapAuth(AuthProvider auth) => ChangeNotifierProvider.value(
      value: auth,
      child: const MaterialApp(home: AuthScreen()),
    );

Widget _wrapCheckout({
  required double amount,
  required String itemTitle,
  required String itemType,
  bool? hasMerchandise,
  required UserAccount user,
  CartProvider? cartProv,
}) {
  final cart = cartProv ?? CartProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>.value(value: cart),
    ],
    child: MaterialApp(
      home: CheckoutScreen(
        amount: amount,
        itemTitle: itemTitle,
        itemType: itemType,
        hasMerchandise: hasMerchandise,
        user: user,
      ),
    ),
  );
}

void main() {
  tearDown(() {
    ApiClient.httpClient = http.Client();
  });

  group('Auth Screen Widget Tests', () {
    testWidgets('Wrong password shows red error text under the sign-in form', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = AuthProvider(userService: _FakeUserService());
      await tester.pumpWidget(_wrapAuth(auth));

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
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fake = _FakeUserService();
      await tester.pumpWidget(_wrapAuth(AuthProvider(userService: fake)));

      await tester.tap(find.text('Forgot Password / Username?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Account Email'), 'nobody@example.com');
      await tester.tap(find.text('Send reset code'));
      await tester.pumpAndSettle();

      expect(fake.forgotCalled, isTrue);
      expect(find.textContaining("If an account exists for this email"), findsOneWidget);
      expect(find.textContaining('not found'), findsNothing);
    });
  });

  group('Requirement A1: Shipping Address Form on Merch Checkout Tests', () {
    final testUser = UserAccount(
      id: 77,
      email: 'buyer@example.com',
      displayName: 'Alex Buyer',
      country: 'US',
    );

    testWidgets('Shipping address form is hidden when checking out track/digital item', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapCheckout(
        amount: 19.99,
        itemTitle: 'Midnight Synth Beat',
        itemType: 'track',
        hasMerchandise: false,
        user: testUser,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shipping_address_section')), findsNothing);
      expect(find.byKey(const Key('shipping_full_name')), findsNothing);
    });

    testWidgets('Shipping address form appears when checking out merchandise', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapCheckout(
        amount: 35.00,
        itemTitle: 'Sound Marketplace Hoodie (L)',
        itemType: 'merchandise',
        hasMerchandise: true,
        user: testUser,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shipping_address_section')), findsOneWidget);
      expect(find.byKey(const Key('shipping_full_name')), findsOneWidget);
      expect(find.byKey(const Key('shipping_line1')), findsOneWidget);
      expect(find.byKey(const Key('shipping_city')), findsOneWidget);
      expect(find.byKey(const Key('shipping_postal_code')), findsOneWidget);
      expect(find.byKey(const Key('shipping_country_code')), findsOneWidget);
    });

    testWidgets('Client-side validation rejects empty shipping fields on merchandise checkout', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapCheckout(
        amount: 35.00,
        itemTitle: 'Producer Cap',
        itemType: 'merchandise',
        hasMerchandise: true,
        user: testUser,
      ));
      await tester.pumpAndSettle();

      // Clear the pre-filled fields
      await tester.enterText(find.byKey(const Key('shipping_full_name')), '');
      await tester.enterText(find.byKey(const Key('shipping_line1')), '');
      await tester.enterText(find.byKey(const Key('shipping_city')), '');
      await tester.enterText(find.byKey(const Key('shipping_postal_code')), '');
      await tester.enterText(find.byKey(const Key('shipping_country_code')), '');

      // Scroll to Pay button and tap
      final payBtn = find.byKey(const Key('checkout_pay_button'));
      await tester.ensureVisible(payBtn);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      // Client validation messages must be visible
      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Street address is required'), findsOneWidget);
      expect(find.text('City is required'), findsOneWidget);
      expect(find.text('Postal code is required'), findsOneWidget);
    });

    testWidgets('Server error on missing shipping address is displayed in red under the form', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ApiClient.httpClient = MockClient((request) async {
        if (request.url.path.contains('/saved-cards')) {
          return http.Response('{"success": true, "data": []}', 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/checkout') {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Shipping address is required for merchandise orders',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": true}', 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(_wrapCheckout(
        amount: 35.00,
        itemTitle: 'Sound Marketplace Hoodie (L)',
        itemType: 'merchandise',
        hasMerchandise: true,
        user: testUser,
      ));
      await tester.pumpAndSettle();

      // Fill in valid shipping address details so client validation passes
      await tester.enterText(find.byKey(const Key('shipping_full_name')), 'Alex Buyer');
      await tester.enterText(find.byKey(const Key('shipping_line1')), '123 Main St');
      await tester.enterText(find.byKey(const Key('shipping_city')), 'Los Angeles');
      await tester.enterText(find.byKey(const Key('shipping_postal_code')), '90210');
      await tester.enterText(find.byKey(const Key('shipping_country_code')), 'US');

      // Fill in card fields
      await tester.enterText(find.widgetWithText(TextFormField, 'Card Number'), '4242424242424242');
      await tester.enterText(find.widgetWithText(TextFormField, 'MM / YY'), '12/34');
      await tester.enterText(find.widgetWithText(TextFormField, 'CVC'), '123');
      await tester.enterText(find.widgetWithText(TextFormField, 'ZIP / Postal'), '90210');

      final payBtn = find.byKey(const Key('checkout_pay_button'));
      await tester.ensureVisible(payBtn);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      final errorTextFinder = find.byKey(const Key('checkout_server_error_text'));
      expect(errorTextFinder, findsOneWidget);
      expect(tester.widget<Text>(errorTextFinder).data, contains('Shipping address is required for merchandise orders'));
      expect(tester.widget<Text>(errorTextFinder).style?.color, Colors.redAccent);
    });
  });

  group('Requirement A2: Admin Moderation Screen Widget Tests', () {
    testWidgets('Admin moderation screen renders pending queue items and approve/reject actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ApiClient.httpClient = MockClient((request) async {
        if (request.url.path == '/api/admin/moderation/queue') {
          final queueResponse = {
            'success': true,
            'message': 'Queue retrieved',
            'data': {
              'items': [
                {
                  'id': 101,
                  'title': 'Vintage Drum Machine T-Shirt',
                  'price': 29.99,
                  'categoryName': 'Apparel',
                  'stockQuantity': 15,
                  'sellerEmail': 'artist@example.com',
                  'moderationStatus': 'PENDING',
                },
              ],
              'page': 0,
              'size': 20,
              'totalElements': 1,
              'totalPages': 1,
              'hasNext': false,
            },
          };
          return http.Response(jsonEncode(queueResponse), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"success": false}', 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AdminModerationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Merchandise Moderation'), findsOneWidget);
      expect(find.text('Vintage Drum Machine T-Shirt'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.byKey(const Key('approve_button_101')), findsOneWidget);
      expect(find.byKey(const Key('reject_button_101')), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('Admin moderation entry is hidden for non-admins and visible for admins in ProfileScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final nonAdminUser = UserAccount(
        id: 1,
        email: 'fan@example.com',
        displayName: 'Regular Fan',
        roles: ['ROLE_CONSUMER'],
      );

      final adminUser = UserAccount(
        id: 2,
        email: 'admin@example.com',
        displayName: 'Site Admin',
        roles: ['ROLE_ADMIN'],
      );

      final authProv = AuthProvider();
      authProv.setUserForTesting(nonAdminUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<MarketplaceProvider>(create: (_) => MarketplaceProvider()),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Non-admin: Admin Portal should NOT be found
      expect(find.text('Admin Portal'), findsNothing);

      // Now set admin user
      authProv.setUserForTesting(adminUser);
      await tester.pumpAndSettle();

      // Admin: Admin Portal should be visible
      expect(find.text('Admin Portal'), findsOneWidget);
      expect(find.text('Review and approve or reject seller merchandise submissions before they appear in public search.'), findsOneWidget);
    });
  });

  group('Requirement B1: Library Screen Widget Tests', () {
    testWidgets('Library screen renders purchased tracks and Download button', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ApiClient.httpClient = MockClient((request) async {
        if (request.url.path == '/api/library') {
          final libraryResponse = {
            'success': true,
            'data': {
              'items': [
                {
                  'id': 55,
                  'title': 'Neon Horizon Loop',
                  'artistName': 'Synth Master',
                  'price': 4.99,
                  'genre': 'Synthwave',
                },
              ],
              'page': 0,
              'size': 20,
              'totalElements': 1,
              'totalPages': 1,
              'hasNext': false,
            },
          };
          return http.Response(jsonEncode(libraryResponse), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"success": false}', 404);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Purchased Library'), findsOneWidget);
      expect(find.text('Neon Horizon Loop'), findsOneWidget);
      expect(find.byKey(const Key('download_button_55')), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });
  });
}
