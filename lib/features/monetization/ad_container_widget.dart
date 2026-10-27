import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/cloud_sync_service.dart';
import 'premium_dialog.dart';

/// Containerized Silent Ad Frame.
///
/// Designed to adhere strictly to your instructions:
/// 1. Silent & non-intrusive: never plays uninvited audio or freezes UI.
/// 2. Contained: strictly bounded (e.g. 64dp bottom banner), never covering full app.
/// 3. Manual Container Dismissal (Safety Hatch): If an ad fails to close or has no close button,
///    the user can tap the prominent top-right [✕] container button to collapse the container.
/// 4. Ad-Free Premium Awareness: If user has subscribed (₹10/mo), returns an empty widget.
class ContainerizedAdWidget extends StatefulWidget {
  final bool isBottomBanner;

  const ContainerizedAdWidget({
    super.key,
    this.isBottomBanner = true,
  });

  @override
  State<ContainerizedAdWidget> createState() => _ContainerizedAdWidgetState();
}

class _ContainerizedAdWidgetState extends State<ContainerizedAdWidget> {
  bool _isManuallyDismissed = false;

  @override
  Widget build(BuildContext context) {
    final cloudSync = context.watch<CloudSyncService?>();
    final isPremium = cloudSync?.isPremium ?? false;

    // Zero ads for premium subscribers
    if (isPremium || _isManuallyDismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 36, 10),
            child: Row(
              children: [
                // Ad Badge & Icon
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SyncTask Pure Sponsor',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Fast, native, local-first to-do manager for all devices.',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // ₹10/mo Ad-Free Prompt
                InkWell(
                  onTap: () => showPremiumDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Remove Ads ₹10/mo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top-Right Safety Container Close Button (Emergency Dismissal)
          Positioned(
            top: 4,
            right: 4,
            child: Tooltip(
              message: 'Close Ad Container',
              child: InkWell(
                onTap: () => setState(() => _isManuallyDismissed = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
