import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/cloud_sync_service.dart';
import '../../monetization/premium_dialog.dart';
import '../../settings/settings_page.dart';
import '../../tasks/task_controller.dart';

/// Interactive Cloud Sync Status Button for SyncTask Pure.
/// Displays live MongoDB Atlas sync status in the AppBar and provides
/// one-tap cloud backup, sync now, and account management.
class CloudSyncStatusButton extends StatelessWidget {
  const CloudSyncStatusButton({super.key});

  String _formatLastSync(int timestamp) {
    if (timestamp <= 0) return 'Never synced';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showCloudSheet(BuildContext context, CloudSyncService cloudSync) {
    final theme = Theme.of(context);
    final user = cloudSync.currentUser;
    final isAuthed = cloudSync.isAuthenticated;
    final isPremium = cloudSync.isPremium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      isAuthed ? Icons.cloud_done : Icons.cloud_queue,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAuthed ? 'Cloud Backup Active' : 'Cloud Backup & Sync',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          isAuthed
                              ? (user?.email ?? 'Connected to MongoDB Atlas')
                              : 'Sync tasks across all devices via Render',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            'Ad-Free',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              if (isAuthed) ...[
                // Sync status details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Last Synced', style: TextStyle(fontSize: 13)),
                          Text(
                            _formatLastSync(cloudSync.lastSyncTimestamp),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Backend', style: TextStyle(fontSize: 13)),
                          Flexible(
                            child: Text(
                              'Render + MongoDB Atlas',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (cloudSync.lastError != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cloudSync.lastError!,
                                style: const TextStyle(fontSize: 11, color: Colors.orange),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: cloudSync.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(cloudSync.isSyncing ? 'Syncing...' : 'Sync Now'),
                        onPressed: cloudSync.isSyncing
                            ? null
                            : () async {
                                final taskCtrl = context.read<TaskController>();
                                await cloudSync.syncWithCloud(taskCtrl.repo);
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cloud sync completed with MongoDB Atlas!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        );
                      },
                      child: const Text('Settings'),
                    ),
                  ],
                ),
              ] else ...[
                // Unauthenticated: Explain benefits & offer Quick Google Sign-In
                const Text(
                  'Sign in to automatically back up your to-dos, keep your devices updated in real-time, and manage your Ad-Free subscription.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Sign in with Google'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showSignInDialog(context, cloudSync);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!isPremium)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.star, size: 16, color: Colors.amber),
                        label: const Text('₹10/mo'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showPremiumDialog(context);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSignInDialog(BuildContext context, CloudSyncService cloudSync) {
    final emailCtrl = TextEditingController(text: 'user@gmail.com');
    final nameCtrl = TextEditingController(text: 'SyncTask User');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_circle, color: Colors.blue),
            SizedBox(width: 8),
            Text('Sign in with Google'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign in to back up and sync your tasks securely to MongoDB Atlas via Render.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign In'),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await cloudSync.signInWithGoogle(
                idToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
                email: emailCtrl.text.trim(),
                displayName: nameCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Signed in as ${emailCtrl.text.trim()}! Initializing cloud sync...'
                          : 'Sign-in failed. Please verify internet connection.',
                    ),
                  ),
                );
                if (success) {
                  final taskCtrl = context.read<TaskController>();
                  await cloudSync.syncWithCloud(taskCtrl.repo);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudSync = context.watch<CloudSyncService?>();
    if (cloudSync == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isAuthed = cloudSync.isAuthenticated;
    final isSyncing = cloudSync.isSyncing;
    final hasError = cloudSync.lastError != null;

    IconData icon;
    Color? iconColor;
    String tooltip;

    if (isSyncing) {
      icon = Icons.cloud_sync_outlined;
      iconColor = theme.colorScheme.primary;
      tooltip = 'Syncing with MongoDB Atlas...';
    } else if (isAuthed) {
      if (hasError) {
        icon = Icons.cloud_off_outlined;
        iconColor = Colors.orange;
        tooltip = 'Cloud Sync Warning: Tap for details';
      } else {
        icon = Icons.cloud_done_outlined;
        iconColor = const Color(0xFF16A34A);
        tooltip = 'Cloud Backup Active (MongoDB Atlas)';
      }
    } else {
      icon = Icons.cloud_queue_outlined;
      iconColor = theme.colorScheme.onSurfaceVariant;
      tooltip = 'Cloud Backup (Tap to Sign In)';
    }

    return IconButton(
      icon: isSyncing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(icon, color: iconColor, size: 22),
      tooltip: tooltip,
      onPressed: () => _showCloudSheet(context, cloudSync),
    );
  }
}
