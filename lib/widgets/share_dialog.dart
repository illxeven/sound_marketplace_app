import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class ShareDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String shareUrl;
  final String itemType;

  const ShareDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.shareUrl,
    this.itemType = 'Track',
  });

  static void show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String shareUrl,
    String itemType = 'Track',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ShareDialog(
        title: title,
        subtitle: subtitle,
        shareUrl: shareUrl,
        itemType: itemType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryCyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_rounded, color: AppTheme.secondaryCyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Share $itemType',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shareUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.secondaryCyan),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Link',
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Link copied to clipboard: $shareUrl'),
                        backgroundColor: AppTheme.successGreen,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Link'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: shareUrl));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Link copied to clipboard: $shareUrl'),
                backgroundColor: AppTheme.successGreen,
                duration: const Duration(seconds: 3),
              ),
            );
          },
        ),
      ],
    );
  }
}
