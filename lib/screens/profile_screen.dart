import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/track.dart';
import '../models/user_account.dart';
import '../models/user_review.dart';
import '../providers/audio_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../services/user_service.dart';
import '../widgets/track_tile.dart';
import 'create_track_screen.dart';
import 'create_merchandise_screen.dart';
import 'artist_storefront_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'admin_moderation_screen.dart';
import 'library_screen.dart';
import 'seller_sales_screen.dart';
import 'order_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  final int? artistId;
  final String? artistName;

  const ProfileScreen({super.key, this.artistId, this.artistName});

  void _showEditProfileDialog(BuildContext context, UserAccount user) {
    final nameController = TextEditingController(text: user.displayName ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');
    final countryController = TextEditingController(text: user.country ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Stage / Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio / Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  labelText: 'Country Code (e.g. US, UK, CA)',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<AuthProvider>().updateProfile(
                    displayName: nameController.text.trim(),
                    bio: bioController.text.trim(),
                    country: countryController.text.trim(),
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Profile updated successfully!' : 'Update failed'),
                    backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Sound Marketplace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AudioPlayerProvider>().stop();
              context.read<AuthProvider>().logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiConfig.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Server Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Spring Boot API Base URL:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://localhost:8080/api',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.setCustomBaseUrl(controller.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('API URL updated to: ${ApiConfig.baseUrl}')),
              );
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mkt = context.watch<MarketplaceProvider>();
    final user = auth.currentUser;

    final isViewingOtherArtist = artistId != null && (user == null || artistId != user.id);
    if (isViewingOtherArtist) {
      return _buildPublicProfile(context, artistId!, artistName ?? 'Artist');
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No user is currently logged in.\nPlease log in to view your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Jump to Discover',
            icon: const Icon(Icons.explore_rounded, color: AppTheme.secondaryCyan),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (ctx) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          Consumer<CartProvider>(
            builder: (context, cart, _) => Badge(
              isLabelVisible: cart.totalItems > 0,
              label: Text('${cart.totalItems}'),
              backgroundColor: AppTheme.accentPink,
              offset: const Offset(-4, 4),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Shopping Cart',
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  if (auth.currentUser != null) {
                    context.read<CartProvider>().loadCart(auth.currentUser!.id);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const CartScreen()),
                  );
                },
              ),
            ),
          ),
          // Developer-only: lets a debug build point at another server. Hidden in release builds.
          if (kDebugMode)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings (debug)',
            onPressed: () => _showServerSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Log Out',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryPurple, Color(0xFF4A1FB8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white24,
                          backgroundImage: user.avatarUrlComputed != null
                              ? NetworkImage(
                                  user.avatarUrlComputed!.startsWith('http')
                                      ? user.avatarUrlComputed!
                                      : ApiConfig.resolve(user.avatarUrlComputed!),
                                )
                              : null,
                          child: user.avatarUrlComputed == null
                              ? Text(
                                  user.effectiveName.isNotEmpty ? user.effectiveName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                                withData: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final file = result.files.first;
                                if (!context.mounted) return;
                                final ok = await context.read<AuthProvider>().uploadAvatar(
                                  avatarPath: file.path,
                                  avatarBytes: file.bytes,
                                  avatarFilename: file.name,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Profile photo updated!' : 'Failed to update photo'),
                                      backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
                                    ),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryCyan,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.surfaceColor, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.effectiveName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${user.id} • ${user.country ?? "Global"}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.secondaryCyan),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: user.canUploadTracks
                                      ? AppTheme.secondaryCyan.withValues(alpha: 0.25)
                                      : Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user.canUploadTracks ? 'ARTIST/PRODUCER' : 'CONSUMER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: user.canUploadTracks ? AppTheme.secondaryCyan : Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      tooltip: 'Edit Profile',
                      onPressed: () => _showEditProfileDialog(context, user),
                    ),
                  ],
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      user.bio!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Admin Moderation Portal (visible only to ADMIN and SUPER_ADMIN)
          if (user.isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Admin Portal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Review and approve or reject seller merchandise submissions before they appear in public search.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('admin_moderation_queue_button'),
                      icon: const Icon(Icons.rule_folder_rounded, size: 18),
                      label: const Text('Open Moderation Queue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const AdminModerationScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Upload Track or Consumer Notice (Strict Upload Location RBAC)
          if (user.canUploadTracks) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: AppTheme.secondaryCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Artist Studio',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Publish tracks, beats, and loops directly to the marketplace.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.music_note_rounded),
                          label: const Text('Upload Track'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => const CreateTrackScreen()),
                            );
                          },
                        ),
                      ),
                      if (user.canUploadMerchandise) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.storefront_rounded),
                            label: const Text('Upload Merch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceColor,
                              foregroundColor: AppTheme.secondaryCyan,
                              side: const BorderSide(color: AppTheme.secondaryCyan, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (ctx) => const CreateMerchandiseScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.canUploadMerchandise) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: const Text('View My Storefront Catalog'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => ArtistStorefrontScreen(
                                artistId: user.id,
                                artistName: user.effectiveName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('seller_sales_button'),
                        icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                        label: const Text('My Sales & Shipping Fulfillment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.secondaryCyan,
                          side: const BorderSide(color: AppTheme.secondaryCyan),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const SellerSalesScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline, color: AppTheme.secondaryCyan, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consumer Account',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'You can stream, like, and purchase sounds. Track uploads are restricted to registered Music Artists and Producers.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Purchased Library Card (Requirement B1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.library_music_rounded, color: AppTheme.secondaryCyan, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Purchased Library',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Download full audio masters for all purchased tracks & beats.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  key: const Key('my_library_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const LibraryScreen()),
                    );
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Purchases & Payment History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Purchase & Order History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                key: const Key('view_all_orders_button'),
                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.secondaryCyan),
                label: const Text('All Orders', style: TextStyle(color: AppTheme.secondaryCyan, fontSize: 13)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const OrderHistoryScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (mkt.paymentHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'No purchases yet.\nBrowse sound kits in the Marketplace tab!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mkt.paymentHistory.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, i) {
                  final p = mkt.paymentHistory[i];
                  final date = p.createdAt != null
                      ? DateFormat.yMMMd().format(p.createdAt!)
                      : 'Recent';

                  return ListTile(
                    leading: const Icon(Icons.receipt_long_rounded, color: AppTheme.successGreen),
                    title: Text(
                      p.merchandiseTitle ?? 'Digital Audio Good',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Charge: ${p.stripeChargeId} • $date',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: Text(
                      '\$${p.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),

          // User / Artist Profile Reviews & Ratings
          ProfileReviewsWidget(targetUserId: user.id, targetUserName: user.effectiveName),
          const SizedBox(height: 24),

          // Log Out Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              label: const Text('Log Out of Sound Marketplace', style: TextStyle(color: AppTheme.errorRed)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showLogoutDialog(context),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPublicProfile(BuildContext context, int targetArtistId, String fallbackName) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService().getPublicProfile(targetArtistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(fallbackName)),
            body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
          );
        }

        final data = snapshot.data;
        final displayName = (data != null && data['displayName'] != null && data['displayName'].toString().isNotEmpty)
            ? data['displayName'].toString()
            : fallbackName;
        final bio = data != null ? data['bio']?.toString() : null;
        final country = data != null ? data['country']?.toString() : 'Global';
        final avatarUrl = data != null ? data['avatarUrl']?.toString() : null;
        final followers = data != null && data['followersCount'] != null ? data['followersCount'] : 0;
        final following = data != null && data['followingCount'] != null ? data['followingCount'] : 0;

        List<Track> tracks = [];
        if (data != null && data['tracks'] is List) {
          tracks = (data['tracks'] as List)
              .map((t) => Track.fromJson(t as Map<String, dynamic>))
              .toList();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('$displayName\'s Profile'),
            actions: [
              IconButton(
                tooltip: 'Jump to Discover',
                icon: const Icon(Icons.explore_rounded, color: AppTheme.secondaryCyan),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (ctx) => const HomeScreen()),
                    (route) => false,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.storefront_rounded),
                tooltip: 'Storefront',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ArtistStorefrontScreen(
                        artistId: targetArtistId,
                        artistName: displayName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Artist Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryPurple, Color(0xFF4A1FB8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(
                                  avatarUrl.startsWith('http')
                                      ? avatarUrl
                                      : ApiConfig.resolve(avatarUrl),
                                )
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#$targetArtistId • $country',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.secondaryCyan),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryCyan.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'VERIFIED ARTIST',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$followers Followers • $following Following',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          bio,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Prominent Artist Storefront CTA Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1538), Color(0xFF16253B)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: AppTheme.secondaryCyan, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$displayName\'s Merch Storefront',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Explore exclusive apparel, physical merch, and sound kits.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 20),
                        label: Text(
                          'Shop $displayName\'s Merchandise Collection',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryCyan,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => ArtistStorefrontScreen(
                                artistId: targetArtistId,
                                artistName: displayName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Artist Released Tracks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tracks by $displayName',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${tracks.length} track${tracks.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tracks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'No tracks uploaded yet.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                ...tracks.map((tr) => TrackTile(track: tr)),

              const SizedBox(height: 24),

              // Profile Reviews & 5-Star Ratings
              ProfileReviewsWidget(targetUserId: targetArtistId, targetUserName: displayName),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class ProfileReviewsWidget extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;

  const ProfileReviewsWidget({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<ProfileReviewsWidget> createState() => _ProfileReviewsWidgetState();
}

class _ProfileReviewsWidgetState extends State<ProfileReviewsWidget> {
  final UserService _userService = UserService();
  List<UserReview> _reviews = [];
  double _averageRating = 0.0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // New review form
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userService.getUserReviews(widget.targetUserId),
        _userService.getUserAverageRating(widget.targetUserId),
      ]);
      final list = results[0] as List<dynamic>;
      final avg = results[1] as double;
      if (mounted) {
        setState(() {
          _reviews = list.map((e) => UserReview.fromJson(e as Map<String, dynamic>)).toList();
          _averageRating = avg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReview() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to leave a review')),
      );
      return;
    }

    final comment = _commentController.text.trim();
    setState(() => _isSubmitting = true);
    try {
      await _userService.addUserReview(
        targetUserId: widget.targetUserId,
        reviewerId: auth.currentUser!.id,
        rating: _selectedRating,
        comment: comment.isNotEmpty ? comment : null,
      );
      _commentController.clear();
      _showForm = false;
      await _loadReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showEditReviewDialog(UserReview review) {
    int editRating = review.rating;
    final editController = TextEditingController(text: review.comment ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Your Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    iconSize: 28,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      star <= editRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () => setDlgState(() => editRating = star),
                  );
                }),
              ),
              const SizedBox(height: 12),
              const Text('Comment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: editController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Share your updated feedback...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dlgCtx);
                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  await _userService.deleteUserReview(review.id, auth.currentUser!.id);
                  _loadReviews();
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dlgCtx);
                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  await _userService.updateUserReview(
                    reviewId: review.id,
                    reviewerId: auth.currentUser!.id,
                    rating: editRating,
                    comment: editController.text.trim().isNotEmpty ? editController.text.trim() : null,
                  );
                  _loadReviews();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    'Reviews & Ratings (${_reviews.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_averageRating > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_averageRating.toStringAsFixed(1)} ★',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              if (auth.isAuthenticated && currentUserId != widget.targetUserId)
                TextButton.icon(
                  icon: Icon(_showForm ? Icons.close : Icons.add_comment_rounded, size: 16),
                  label: Text(_showForm ? 'Cancel' : 'Write Review'),
                  onPressed: () => setState(() => _showForm = !_showForm),
                ),
            ],
          ),
          if (_showForm) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Your Rating:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        iconSize: 26,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          star <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => _selectedRating = star),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment about this artist or creator...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReview,
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Review'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppTheme.primaryPurple)))
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No reviews yet. Be the first to leave feedback for this creator!',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 16),
              itemBuilder: (ctx, index) {
                final r = _reviews[index];
                final isAuthor = currentUserId == r.reviewerId;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryPurple,
                      child: Text(
                        r.reviewerDisplay.isNotEmpty ? r.reviewerDisplay[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r.reviewerDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Row(
                                children: List.generate(5, (starIdx) {
                                  return Icon(
                                    starIdx < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: Colors.amber,
                                    size: 14,
                                  );
                                }),
                              ),
                            ],
                          ),
                          if (r.comment != null && r.comment!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r.comment!, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                          ],
                        ],
                      ),
                    ),
                    if (isAuthor)
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.secondaryCyan),
                        tooltip: 'Edit Review',
                        onPressed: () => _showEditReviewDialog(r),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

