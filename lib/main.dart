import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'config/theme.dart';
import 'providers/audio_player_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/marketplace_provider.dart';
import 'providers/playlist_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Stripe SDK for native mobile platforms (Android/iOS)
  // On Web, flutter_stripe native platform channels are not used
  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_51UPBAGIJMUYm6q5qIo0ymnbtekz5KHlae3IC3bkDSLc0B8YAExaUgijAzkjvzkmpvvOGqT9KI6j8SsXDkdLFnFfB008DutzeYt';
    try {
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Stripe applySettings notice: $e');
    }
  }

  runApp(const SoundMarketplaceApp());
}

class SoundMarketplaceApp extends StatelessWidget {
  const SoundMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initializeUser()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => MarketplaceProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
      ],
      child: MaterialApp(
        title: 'Sound Marketplace',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            // Loading initial state: wait for SharedPreferences session to restore
            if (!auth.isInitialized || (auth.isLoading && auth.currentUser == null)) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                ),
              );
            }
            // Strict Authentication Guard: Unauthenticated visitors must log in or register first
            if (!auth.isAuthenticated) {
              final player = context.read<AudioPlayerProvider>();
              if (player.isPlaying || player.currentTrack != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  player.stop();
                });
              }
              return const AuthScreen();
            }
            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
