import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/merchandise.dart';
import '../services/api_client.dart';
import '../services/json_utils.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Merchandise> _queue = [];
  int _page = 0;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get<Map<String, dynamic>>(
        '/admin/moderation/queue', queryParameters: {'page': '$_page', 'size': '20'},
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      final data = res.data;
      final rawItems = extractItems(data);
      final items = rawItems
          .map((i) => Merchandise.fromJson((i as Map).cast<String, dynamic>()))
          .toList();

      setState(() {
        if (refresh || _page == 0) {
          _queue = items;
        } else {
          _queue.addAll(items);
        }
        _hasNext = pageHasNext(data);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _approveItem(Merchandise item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Approve Merchandise?'),
        content: Text('Are you sure you want to approve "${item.title}" for public marketplace listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient.post<Map<String, dynamic>>(
        '/admin/moderation/merchandise/${item.id}/approve',
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved "${item.title}" successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadQueue(refresh: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${e.message}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _rejectItem(Merchandise item) async {
    String selectedReason = 'INAPPROPRIATE_CONTENT';
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Reject Merchandise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejecting listing: "${item.title}"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 14),
                const Text('Select Reason Code *', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: AppTheme.cardColor,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'INAPPROPRIATE_CONTENT', child: Text('Inappropriate Content')),
                    DropdownMenuItem(value: 'COPYRIGHT_INFRINGEMENT', child: Text('Copyright Infringement')),
                    DropdownMenuItem(value: 'PROHIBITED_GOODS', child: Text('Prohibited Goods')),
                    DropdownMenuItem(value: 'LOW_QUALITY', child: Text('Low Quality Artwork / Description')),
                    DropdownMenuItem(value: 'MISLEADING_INFORMATION', child: Text('Misleading Information')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other Violation')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedReason = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text('Reviewer Note / Feedback', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Explain why this listing was rejected...',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject Listing'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient.post<Map<String, dynamic>>(
        '/admin/moderation/merchandise/${item.id}/reject',
        body: {
          'reasonCode': selectedReason,
          'note': noteController.text.trim(),
        },
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected "${item.title}"'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        _loadQueue(refresh: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${e.message}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchandise Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: () => _loadQueue(refresh: true),
          ),
        ],
      ),
      body: _isLoading && _queue.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : _errorMessage != null && _queue.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _loadQueue(refresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppTheme.surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: AppTheme.successGreen),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Queue is Clear!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All merchandise submissions have been reviewed.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadQueue(refresh: true),
                      color: AppTheme.primaryPurple,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _queue.length + (_hasNext ? 1 : 0),
                        separatorBuilder: (ctx, i) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (index >= _queue.length) {
                            return Center(
                              child: TextButton(
                                onPressed: () {
                                  _page++;
                                  _loadQueue();
                                },
                                child: const Text('Load More'),
                              ),
                            );
                          }

                          final item = _queue[index];
                          final img = item.imageBlob ?? (item.allImages.isNotEmpty ? item.allImages.first : null);

                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 70,
                                          height: 70,
                                          child: img != null
                                              ? Image.memory(img, fit: BoxFit.cover)
                                              : Container(
                                                  color: AppTheme.surfaceColor,
                                                  child: const Icon(Icons.inventory_2_outlined, color: Colors.white38),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                                                  ),
                                                  child: const Text(
                                                    'PENDING',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orangeAccent,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    item.displayCategory,
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.secondaryCyan),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Seller: ${item.sellerDisplay} • Stock: ${item.stockQuantity}',
                                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: AppTheme.secondaryCyan,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.description != null && item.description!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.description!,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        key: Key('reject_button_${item.id}'),
                                        icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.errorRed),
                                        label: const Text('Reject', style: TextStyle(color: AppTheme.errorRed)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.6)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _rejectItem(item),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        key: Key('approve_button_${item.id}'),
                                        icon: const Icon(Icons.check_rounded, size: 16),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _approveItem(item),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
