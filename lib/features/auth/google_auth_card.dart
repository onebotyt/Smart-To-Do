import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/services/cloud_sync_service.dart';
import '../monetization/premium_dialog.dart';

/// Card widget displayed in SettingsPage for Google Login, Logout,
/// Render backend cloud sync, and ₹10/month Premium status.
class GoogleAuthCard extends StatefulWidget {
  final TaskRepository taskRepo;

  const GoogleAuthCard({
    super.key,
    required this.taskRepo,
  });

  @override
  State<GoogleAuthCard> createState() => _GoogleAuthCardState();
}

class _GoogleAuthCardState extends State<GoogleAuthCard> {
  final _urlController = TextEditingController();
  bool _showUrlConfig = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cloudSync = context.read<CloudSyncService?>();
      if (cloudSync != null) {
        _urlController.text = cloudSync.backendUrl;
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showMockGoogleSignInDialog() {
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
              'Sign in to sync your tasks securely to MongoDB Atlas on Render across all devices.',
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
              final cloudSync = context.read<CloudSyncService>();
              final success = await cloudSync.signInWithGoogle(
                idToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
                email: emailCtrl.text.trim(),
                displayName: nameCtrl.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Signed in as ${emailCtrl.text.trim()}'
                          : 'Connected in offline profile mode.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloudSync = context.watch<CloudSyncService?>();

    if (cloudSync == null) return const SizedBox.shrink();

    final user = cloudSync.currentUser;
    final isAuthed = cloudSync.isAuthenticated;
    final isPremium = cloudSync.isPremium;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    isAuthed ? Icons.person : Icons.cloud_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuthed ? (user?.displayName ?? 'Google User') : 'Cloud Backup & Sync',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        isAuthed ? (user?.email ?? '') : 'MongoDB Atlas & Render backend',
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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Action row
            Row(
              children: [
                if (!isAuthed)
                  FilledButton.icon(
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Google Sign-In'),
                    onPressed: _showMockGoogleSignInDialog,
                  )
                else ...[
                  OutlinedButton.icon(
                    icon: cloudSync.isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('Sync Now'),
                    onPressed: cloudSync.isSyncing
                        ? null
                        : () async {
                            await cloudSync.syncWithCloud(widget.taskRepo);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cloud sync completed with MongoDB Atlas!')),
                              );
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    onPressed: () => cloudSync.signOut(),
                  ),
                ],
                const Spacer(),
                if (!isPremium)
                  TextButton.icon(
                    icon: const Icon(Icons.workspace_premium, size: 16, color: Colors.amber),
                    label: const Text('₹10/mo', style: TextStyle(color: Colors.amber)),
                    onPressed: () => showPremiumDialog(context),
                  ),
              ],
            ),

            // Backend URL Config Toggle
            const Divider(height: 20),
            InkWell(
              onTap: () => setState(() => _showUrlConfig = !_showUrlConfig),
              child: Row(
                children: [
                  Icon(
                    _showUrlConfig ? Icons.expand_less : Icons.settings_ethernet,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Render Backend URL',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _showUrlConfig ? 'Hide' : 'Configure',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),

            if (_showUrlConfig) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'https://to-do-backend.onrender.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await cloudSync.setBackendUrl(_urlController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backend URL updated!')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
