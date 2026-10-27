import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:synctask/core/logger/app_logger.dart';
import 'package:synctask/features/sync/sync_controller.dart';

void showDiagnosticLogsModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const DiagnosticLogSheet(),
  );
}

class DiagnosticLogSheet extends StatefulWidget {
  const DiagnosticLogSheet({super.key});

  @override
  State<DiagnosticLogSheet> createState() => _DiagnosticLogSheetState();
}

class _DiagnosticLogSheetState extends State<DiagnosticLogSheet> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = context.read<SyncController>();
    final allLogs = AppLogger().logs;

    final filteredLogs = allLogs.where((l) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'error') return l.level == LogLevel.error;
      return l.category.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList().reversed.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Action & Diagnostic Logs',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${allLogs.length} actions recorded in real time',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear Logs',
                    onPressed: () {
                      AppLogger().clear();
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Action Buttons (Send to GitHub / Copy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.bug_report, size: 18),
                      label: const Text('Send Log to GitHub'),
                      onPressed: () async {
                        final ok = await GitHubLogService.sendLogsToGitHub(
                          deviceId: sync.localDeviceId,
                          deviceName: sync.localDeviceName,
                          detectedIps: sync.discoveredPeers.map((p) => p.ipAddress).toList(),
                          pairedDevicesCount: sync.devices.length,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Opened GitHub Issue with diagnostic logs!'
                                  : 'Diagnostic logs copied to clipboard!'),
                              backgroundColor: ok ? Colors.green.shade700 : null,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    onPressed: () async {
                      final report = AppLogger().generateMarkdownReport(
                        deviceId: sync.localDeviceId,
                        deviceName: sync.localDeviceName,
                        pairedDevicesCount: sync.devices.length,
                      );
                      await Clipboard.setData(ClipboardData(text: report));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Full diagnostic log copied to clipboard!')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${allLogs.length})'),
                  const SizedBox(width: 6),
                  _buildFilterChip('sync', 'Sync'),
                  const SizedBox(width: 6),
                  _buildFilterChip('pairing', 'Pairing'),
                  const SizedBox(width: 6),
                  _buildFilterChip('network', 'Network'),
                  const SizedBox(width: 6),
                  _buildFilterChip('media', 'Media'),
                  const SizedBox(width: 6),
                  _buildFilterChip('error', 'Errors'),
                ],
              ),
            ),
            const Divider(height: 12),

            // Logs List
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        'No logs match the selected filter',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final entry = filteredLogs[index];
                        final isErr = entry.level == LogLevel.error;
                        final isWarn = entry.level == LogLevel.warning;

                        Color bg;
                        if (isErr) {
                          bg = Colors.red.withValues(alpha: 0.12);
                        } else if (isWarn) {
                          bg = Colors.amber.withValues(alpha: 0.12);
                        } else {
                          bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isErr
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : (isWarn
                                      ? Colors.amber.withValues(alpha: 0.3)
                                      : Colors.transparent),
                              width: 0.8,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    entry.formattedTime,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.category.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    entry.levelTag,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isErr
                                          ? Colors.red
                                          : (isWarn ? Colors.amber.shade800 : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: isErr ? Colors.red.shade900 : null,
                                ),
                              ),
                              if (entry.error != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  entry.error!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      visualDensity: VisualDensity.compact,
    );
  }
}
