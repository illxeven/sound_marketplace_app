import 'package:flutter_test/flutter_test.dart';
import 'package:sound_marketplace_app/models/album.dart';
import 'package:sound_marketplace_app/models/track.dart';
import 'package:sound_marketplace_app/providers/catalog_provider.dart';
import 'package:sound_marketplace_app/services/api_client.dart';
import 'package:sound_marketplace_app/services/catalog_service.dart';
import 'package:sound_marketplace_app/services/engagement_service.dart';
import 'package:sound_marketplace_app/services/json_utils.dart';

Track _t(int id, {int plays = 0, int likes = 0}) =>
    Track(id: id, artistId: 1, title: 'Track $id', playsCount: plays, likesCount: likes);

class _FakeCatalog extends CatalogService {
  int pageCalls = 0;

  @override
  Future<PageResult<Track>> getTracksPage({int page = 0, int size = 30, String sort = 'createdAt,desc'}) async {
    pageCalls++;
    return page == 0
        ? PageResult([_t(1, plays: 10, likes: 2), _t(2, plays: 50)], hasNext: true, page: 0)
        : PageResult([_t(3, plays: 5)], hasNext: false, page: page);
  }

  @override
  Future<List<Album>> getAllAlbums() async => [];

  @override
  Future<List<String>> getGenres() async => ['Trap'];
}

class _FakeEngagement extends EngagementService {
  int likeCountCalls = 0;
  bool failLikes = false;

  @override
  Future<Set<int>> getLikedTrackIds() async => {2};

  @override
  Future<int> getTrackLikesCount(int trackId) async {
    likeCountCalls++;
    return 0;
  }

  @override
  Future<void> likeTrack(int trackId, [int? userId]) async {
    if (failLikes) throw ApiException('offline');
  }
}

void main() {
  test('loads a page with counts and liked state, without per-track requests', () async {
    final engagement = _FakeEngagement();
    final catalog = CatalogProvider(catalogService: _FakeCatalog(), engagementService: engagement);
    await catalog.loadCatalog();

    expect(catalog.allTracks.map((t) => t.id), [1, 2]);
    expect(catalog.getTrackPlays(2), 50);
    expect(catalog.getTrackLikes(1), 2);
    expect(catalog.isTrackLiked(2), isTrue, reason: 'hearts survive an app restart');
    expect(engagement.likeCountCalls, 0, reason: 'no N+1 like-count requests');
    expect(catalog.trendingTracks.first.id, 2);
  });

  test('infinite scroll appends the next page and stops at the end', () async {
    final service = _FakeCatalog();
    final catalog = CatalogProvider(catalogService: service, engagementService: _FakeEngagement());
    await catalog.loadCatalog();
    await catalog.loadMoreTracks();
    await catalog.loadMoreTracks(); // no more pages: no extra call

    expect(catalog.allTracks.map((t) => t.id), [1, 2, 3]);
    expect(catalog.hasMore, isFalse);
    expect(service.pageCalls, 2);
  });

  test('play counts take the server number from the play-event response', () async {
    final catalog = CatalogProvider(catalogService: _FakeCatalog(), engagementService: _FakeEngagement());
    await catalog.loadCatalog();
    catalog.applyPlayCount(1, 11);
    expect(catalog.getTrackPlays(1), 11);
  });

  test('a failed like rolls back the heart and the count', () async {
    final engagement = _FakeEngagement()..failLikes = true;
    final catalog = CatalogProvider(catalogService: _FakeCatalog(), engagementService: engagement);
    await catalog.loadCatalog();
    await catalog.toggleLike(1);
    expect(catalog.isTrackLiked(1), isFalse);
    expect(catalog.getTrackLikes(1), 2);
  });

  test('sign-out reset clears liked tracks', () async {
    final catalog = CatalogProvider(catalogService: _FakeCatalog(), engagementService: _FakeEngagement());
    await catalog.loadCatalog();
    catalog.reset();
    expect(catalog.isTrackLiked(2), isFalse);
  });

  test('Track parses the v2 summary shape and beat listings', () {
    final t = Track.fromJson({
      'id': 7, 'title': 'Night Drive', 'artistId': 3, 'artistName': 'Kay', 'genre': 'Trap Beats',
      'price': 29.99, 'playCount': 1200, 'likeCount': 45, 'coverUrl': '/api/tracks/7/cover',
    });
    expect(t.playsCount, 1200);
    expect(t.likesCount, 45);
    expect(t.coverImageFullUrl, endsWith('/api/tracks/7/cover'));
    expect(t.isBeat, isTrue);

    final beat = Track.fromMarketplaceItem({
      'id': 9, 'itemType': 'BEAT', 'title': 'Cold', 'price': 19, 'sellerId': 4, 'sellerName': 'Prod X',
    });
    expect(beat.artistName, 'Prod X');
    expect(beat.price, 19.0);
  });

  test('extractItems handles plain lists and pages', () {
    expect(extractItems([1, 2]), [1, 2]);
    expect(extractItems({'items': [3], 'hasNext': true}), [3]);
    expect(pageHasNext({'items': [], 'hasNext': true}), isTrue);
  });
}
