import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/playlist.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/track_tile.dart';
import '../config/api_config.dart';
import 'home_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<PlaylistProvider>().loadPlaylists(auth.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    final titleController = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Playlist Title',
                  hintText: 'e.g. Late Night Synth Sessions',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Public Playlist'),
                subtitle: const Text('Anyone can listen to this playlist'),
                value: isPublic,
                activeColor: AppTheme.primaryPurple,
                onChanged: (val) => setModalState(() => isPublic = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);

                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  final created = await context.read<PlaylistProvider>().createPlaylist(
                        userId: auth.currentUser!.id,
                        title: title,
                        isPublic: isPublic,
                      );
                  if (context.mounted && created != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Created playlist "${created.title}"')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistTracks(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.accentPink],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          '${playlist.tracks.length} tracks • By ${playlist.userEmail?.split('@').first ?? 'User'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: playlist.tracks.isEmpty
                  ? const Center(
                      child: Text(
                        'No tracks in this playlist yet.\nAdd tracks from the Discover tab!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: playlist.tracks.length,
                      itemBuilder: (context, index) {
                        return TrackTile(
                          track: playlist.tracks[index],
                          playlistQueue: playlist.tracks,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistList(List<Playlist> playlists, bool isMyPlaylists) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              isMyPlaylists ? 'You have no playlists yet' : 'No public playlists found',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            if (isMyPlaylists) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showCreatePlaylistDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Playlist'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple,
                    index % 2 == 0 ? AppTheme.secondaryCyan : AppTheme.accentPink,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
            ),
            title: Text(
              pl.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${pl.tracks.length} tracks • ${pl.isPublic ? 'Public' : 'Private'}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
            onTap: () => _showPlaylistTracks(pl),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
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
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Playlist',
            onPressed: _showCreatePlaylistDialog,
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              if (user == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryPurple,
                        backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                            ? NetworkImage(
                                user.avatarUrl!.startsWith('http')
                                    ? user.avatarUrl!
                                    : ApiConfig.resolve(user.avatarUrl!),
                              )
                            : null,
                        child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                            ? Text(
                                user.displayName?.isNotEmpty == true
                                    ? user.displayName![0].toUpperCase()
                                    : user.email[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 85),
                        child: Text(
                          user.effectiveName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Public Playlists'),
            Tab(text: 'My Playlists'),
          ],
        ),
      ),
      body: Consumer2<PlaylistProvider, AuthProvider>(
        builder: (context, playlistProv, auth, child) {
          if (playlistProv.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPlaylistList(playlistProv.publicPlaylists, false),
              _buildPlaylistList(playlistProv.userPlaylists, true),
            ],
          );
        },
      ),
    );
  }
}
