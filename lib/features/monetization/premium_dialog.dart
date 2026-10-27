import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/cloud_sync_service.dart';

/// Shows the ₹10/month Ad-Free Premium Plan Bottom Sheet / Dialog.
void showPremiumDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _PremiumPlanSheet(),
  );
}

class _PremiumPlanSheet extends StatefulWidget {
  const _PremiumPlanSheet();

  @override
  State<_PremiumPlanSheet> createState() => _PremiumPlanSheetState();
}

class _PremiumPlanSheetState extends State<_PremiumPlanSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloudSync = context.watch<CloudSyncService?>();
    final isPremium = cloudSync?.isPremium ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.amber,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'SyncTask Pure Premium',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPremium
                ? 'Your Ad-Free subscription is currently active! 🎉'
                : '100% Ad-Free Experience + MongoDB Cloud Sync Backup',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Feature list
          _buildFeatureRow(theme, Icons.block, 'Completely remove all banner and open ads'),
          _buildFeatureRow(theme, Icons.cloud_done, 'Instant MongoDB Atlas cloud backup on Render'),
          _buildFeatureRow(theme, Icons.speed, 'Maximum performance & zero distraction on mobile'),
          const SizedBox(height: 24),

          // Price Tag Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ad-Free Monthly Pass',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Cancel anytime via Google Play',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Text(
                  '₹10 / mo',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: isPremium || _isLoading
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isLoading = true);
                      if (cloudSync != null) {
                        await cloudSync.activateAdFreePlan();
                      }
                      if (mounted) {
                        setState(() => _isLoading = false);
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Ad-Free Premium Plan Activated! Enjoy an uninterrupted experience.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isPremium ? 'Already Subscribed' : 'Upgrade for ₹10 / month'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
