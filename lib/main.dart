import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/audio_player_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/marketplace_provider.dart';
import 'providers/playlist_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

/// Stripe publishable key, passed at build time:
///   --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
const String _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock-screen / notification controls and background playback. Must run before any AudioPlayer.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.soundmarketplace.playback',
    androidNotificationChannelName: 'Sound Marketplace playback',
    androidNotificationOngoing: true,
  );

  if (!kIsWeb && _stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = _stripePublishableKey;
    try {
      await Stripe.instance.applySettings();
    } on Exception catch (e) {
      // Platform/config errors from the Stripe SDK; payments stay disabled, the app still runs.
      debugPrint('[stripe] settings not applied: $e');
    }
  } else if (!kIsWeb) {
    debugPrint('[stripe] STRIPE_PUBLISHABLE_KEY not set; card payments are disabled in this build');
  }

  // Build providers up front so sign-out can clear every user-specific one.
  final auth = AuthProvider();
  final catalog = CatalogProvider();
  final playlists = PlaylistProvider();
  final marketplace = MarketplaceProvider();
  final cart = CartProvider();
  final player = AudioPlayerProvider()..onPlayCount = catalog.applyPlayCount;

  auth
    ..addSignOutListener(player.reset)
    ..addSignOutListener(catalog.reset)
    ..addSignOutListener(playlists.reset)
    ..addSignOutListener(marketplace.reset)
    ..addSignOutListener(cart.reset);

  runApp(SoundMarketplaceApp(
    auth: auth,
    catalog: catalog,
    playlists: playlists,
    marketplace: marketplace,
    cart: cart,
    player: player,
  ));
  await auth.initializeUser();
}

class SoundMarketplaceApp extends StatelessWidget {
  const SoundMarketplaceApp({
    super.key,
    required this.auth,
    required this.catalog,
    required this.playlists,
    required this.marketplace,
    required this.cart,
    required this.player,
  });

  final AuthProvider auth;
  final CatalogProvider catalog;
  final PlaylistProvider playlists;
  final MarketplaceProvider marketplace;
  final CartProvider cart;
  final AudioPlayerProvider player;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider.value(value: playlists),
        ChangeNotifierProvider.value(value: marketplace),
        ChangeNotifierProvider.value(value: cart),
        ChangeNotifierProvider.value(value: player),
      ],
      child: MaterialApp(
        title: 'Sound Marketplace',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Selector<AuthProvider, (bool, bool)>(
          selector: (_, a) => (a.isInitialized, a.isAuthenticated),
          builder: (context, state, _) {
            final (initialized, signedIn) = state;
            if (!initialized) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
              );
            }
            return signedIn ? const HomeScreen() : const AuthScreen();
          },
        ),
      ),
    );
  }
}
