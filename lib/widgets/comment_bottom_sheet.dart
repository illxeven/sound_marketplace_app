import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/track.dart';
import '../models/track_comment.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';

class CommentBottomSheet extends StatefulWidget {
  final Track track;

  const CommentBottomSheet({super.key, required this.track});

  static void show(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentBottomSheet(track: track),
    );
  }

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  TrackComment? _replyingToComment;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadComments(widget.track.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dt);
  }

  String _getAuthorName(TrackComment c) {
    if (c.userDisplayName != null && c.userDisplayName!.trim().isNotEmpty) {
      return c.userDisplayName!.trim();
    }
    return 'User #${c.userId ?? "Anon"}';
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final parentId = _replyingToComment?.id;
    final catalog = context.read<CatalogProvider>();
    final success = await catalog.addComment(
      widget.track.id,
      auth.currentUser!.id,
      text,
      parentCommentId: parentId,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (success) {
          _commentController.clear();
          _replyingToComment = null;
        }
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    }
  }

  Widget _buildCommentCard({
    required TrackComment comment,
    required Map<int, TrackComment> commentMap,
    bool isReply = false,
  }) {
    final authorName = _getAuthorName(comment);
    final dateStr = _formatDate(comment.createdAt);

    TrackComment? parentComment;
    if (isReply && comment.parentCommentId != null) {
      parentComment = commentMap[comment.parentCommentId];
    }
    final parentAuthor = parentComment != null ? _getAuthorName(parentComment) : null;

    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 28 : 0,
        top: 6,
        bottom: 6,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply ? AppTheme.surfaceColor.withValues(alpha: 0.7) : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReply
              ? AppTheme.secondaryCyan.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isReply ? 11 : 13,
                backgroundColor: isReply
                    ? AppTheme.secondaryCyan.withValues(alpha: 0.25)
                    : AppTheme.primaryPurple.withValues(alpha: 0.35),
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: isReply ? 9 : 11,
                    fontWeight: FontWeight.bold,
                    color: isReply ? AppTheme.secondaryCyan : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isReply ? 12 : 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (parentAuthor != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_right_rounded, size: 16, color: AppTheme.textSecondary),
                          Flexible(
                            child: Text(
                              '@$parentAuthor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryCyan,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.commentText,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (context.read<AuthProvider>().currentUser?.id == comment.userId) ...[
                InkWell(
                  onTap: () => _showEditCommentDialog(comment),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.secondaryCyan),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final auth = context.read<AuthProvider>();
                    if (auth.currentUser != null) {
                      await context.read<CatalogProvider>().deleteComment(
                        comment.id,
                        widget.track.id,
                        auth.currentUser!.id,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.errorRed),
                        SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: () {
                  setState(() => _replyingToComment = comment);
                  _focusNode.requestFocus();
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_rounded, size: 14, color: AppTheme.secondaryCyan),
                      SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(TrackComment comment) {
    final controller = TextEditingController(text: comment.commentText);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;
              Navigator.pop(dlgCtx);
              final auth = context.read<AuthProvider>();
              if (auth.currentUser != null) {
                await context.read<CatalogProvider>().updateComment(
                  comment.id,
                  widget.track.id,
                  auth.currentUser!.id,
                  newText,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + keyboardPadding,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.secondaryCyan, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comments • ${widget.track.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Comments list
          Expanded(
            child: Consumer<CatalogProvider>(
              builder: (context, catalog, child) {
                final comments = catalog.getCommentsForTrack(widget.track.id);

                if (comments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No comments yet. Drop the first comment below!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                // Organize into threaded hierarchy
                final Map<int, TrackComment> commentMap = {
                  for (final c in comments) c.id: c
                };

                final Map<int, List<TrackComment>> repliesMap = {};
                final List<TrackComment> rootComments = [];

                for (final c in comments) {
                  if (c.parentCommentId != null && commentMap.containsKey(c.parentCommentId)) {
                    repliesMap.putIfAbsent(c.parentCommentId!, () => []).add(c);
                  } else {
                    rootComments.add(c);
                  }
                }

                // Sort replies chronologically (older first) for natural conversation flow
                for (final list in repliesMap.values) {
                  list.sort((a, b) {
                    if (a.createdAt == null || b.createdAt == null) return 0;
                    return a.createdAt!.compareTo(b.createdAt!);
                  });
                }

                // Helper to collect all nested descendant replies for a comment
                List<TrackComment> getDescendantReplies(int parentId) {
                  final List<TrackComment> result = [];
                  final direct = repliesMap[parentId] ?? [];
                  for (final reply in direct) {
                    result.add(reply);
                    result.addAll(getDescendantReplies(reply.id));
                  }
                  return result;
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: rootComments.length,
                  itemBuilder: (context, index) {
                    final root = rootComments[index];
                    final descendants = getDescendantReplies(root.id);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentCard(
                          comment: root,
                          commentMap: commentMap,
                          isReply: false,
                        ),
                        for (final reply in descendants)
                          _buildCommentCard(
                            comment: reply,
                            commentMap: commentMap,
                            isReply: true,
                          ),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Replying to banner (if active)
          if (_replyingToComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: AppTheme.secondaryCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Replying to ',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        children: [
                          TextSpan(
                            text: '@${_getAuthorName(_replyingToComment!)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _replyingToComment = null),
                  ),
                ],
              ),
            ),

          // Comment input bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + keyboardPadding),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: _replyingToComment != null
                          ? 'Reply to @${_getAuthorName(_replyingToComment!)}...'
                          : 'Add a comment (e.g. "That beat is fire 🔥")...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: AppTheme.secondaryCyan),
                  onPressed: _isSubmitting ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
