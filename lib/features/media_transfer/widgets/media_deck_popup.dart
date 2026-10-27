import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/platform/native_media_service.dart';

/// Floating Deck-of-Cards thumbnail popup that animates out of the floating bubble.
/// Multiple images stack sequentially on top of each other with card rotations.
class MediaDeckBubblePopup extends StatefulWidget {
  final List<MediaTransferItem> items;
  final VoidCallback onDismiss;
  final VoidCallback onTapDeck;

  const MediaDeckBubblePopup({
    super.key,
    required this.items,
    required this.onDismiss,
    required this.onTapDeck,
  });

  @override
  State<MediaDeckBubblePopup> createState() => _MediaDeckBubblePopupState();
}

class _MediaDeckBubblePopupState extends State<MediaDeckBubblePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool _isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topItems = widget.items.take(4).toList().reversed.toList();
    final count = widget.items.length;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: _animCtrl.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scaleAnim.value,
            alignment: Alignment.bottomRight,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTapDeck,
        child: Container(
          width: 96,
          height: 104,
          padding: const EdgeInsets.all(4),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Stacked cards in reverse order (bottom to top)
              for (int i = 0; i < topItems.length; i++) ...[
                _buildCard(
                  item: topItems[i],
                  index: i,
                  total: topItems.length,
                  isDark: isDark,
                  isTop: i == topItems.length - 1,
                ),
              ],

              // Card Count Badge (if > 1)
              if (count > 1)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required MediaTransferItem item,
    required int index,
    required int total,
    required bool isDark,
    required bool isTop,
  }) {
    // Physical deck rotation angles: bottom slightly rotated left, next right, top straight
    final rotations = [-0.10, 0.08, -0.04, 0.0];
    final rotIdx = (index + (4 - total)).clamp(0, 3);
    final angle = rotations[rotIdx];
    final yOffset = (total - 1 - index) * -4.0;
    final file = File(item.filePath);
    final isImg = item.filePath.isNotEmpty && file.existsSync() && _isImage(item.filePath);

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTop
                  ? const Color(0xFF3880FF)
                  : (isDark ? Colors.white24 : Colors.black12),
              width: isTop ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isTop ? 0.35 : 0.18),
                blurRadius: isTop ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isImg
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackIcon(item),
                )
              : _buildFallbackIcon(item),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(MediaTransferItem item) {
    final ext = item.fileName.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    if (['mp4', 'mkv', 'mov'].contains(ext)) {
      icon = Icons.videocam;
      color = Colors.deepPurpleAccent;
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      icon = Icons.description;
      color = Colors.redAccent;
    } else if (['zip', 'rar', '7z'].contains(ext)) {
      icon = Icons.folder_zip;
      color = Colors.amber;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.blue;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 2),
          Text(
            ext.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Full Modal "Deck of Cards Gallery" allowing swipe, preview,
/// share, open file, and folder exploration.
class DeckOfCardsGalleryModal extends StatefulWidget {
  final List<MediaTransferItem> items;
  final VoidCallback onDismissAll;

  const DeckOfCardsGalleryModal({
    super.key,
    required this.items,
    required this.onDismissAll,
  });

  @override
  State<DeckOfCardsGalleryModal> createState() => _DeckOfCardsGalleryModalState();
}

class _DeckOfCardsGalleryModalState extends State<DeckOfCardsGalleryModal> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = widget.items.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.style_outlined, color: Color(0xFF3880FF), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Received Media (${_currentIndex + 1}/$total)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          widget.onDismissAll();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                // Card Carousel / Deck Swiper
                SizedBox(
                  height: 320,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: total,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final file = File(item.filePath);
                      final isImg = item.filePath.isNotEmpty && file.existsSync() && _isImage(item.filePath);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isImg
                              ? GestureDetector(
                                  onTap: () => _openLightbox(context, file),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(file, fit: BoxFit.cover),
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildLargeFilePreview(item),
                        ),
                      );
                    },
                  ),
                ),

                // Current Item Details
                if (total > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          widget.items[_currentIndex].fileName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From ${widget.items[_currentIndex].senderName} • ${widget.items[_currentIndex].formattedSize}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons (Open, Share, Dismiss)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      if (Platform.isAndroid)
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Share'),
                            onPressed: () {
                              final item = widget.items[_currentIndex];
                              NativeMediaService.shareFile(filePath: item.filePath);
                            },
                          ),
                        ),
                      if (Platform.isAndroid) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open'),
                          onPressed: () {
                            final item = widget.items[_currentIndex];
                            OpenFilex.open(item.filePath);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeFilePreview(MediaTransferItem item) {
    final ext = item.fileName.split('.').last.toUpperCase();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3880FF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insert_drive_file, size: 54, color: Color(0xFF3880FF)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3880FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ext,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }
}
