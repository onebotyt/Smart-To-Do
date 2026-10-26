import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synctask/features/floating_panel/floating_task_panel.dart';
import 'package:synctask/features/settings/settings_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';

class FloatingBubbleOverlay extends StatefulWidget {
  final Widget child;

  const FloatingBubbleOverlay({super.key, required this.child});

  @override
  State<FloatingBubbleOverlay> createState() => _FloatingBubbleOverlayState();
}

class _FloatingBubbleOverlayState extends State<FloatingBubbleOverlay> {
  Offset? _position;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    if (!settings.isFloatingBubbleEnabled) {
      return widget.child;
    }

    final taskController = context.watch<TaskController>();
    final pendingCount =
        taskController.tasks.where((t) => !t.completed).length;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Default position: bottom-right corner with margin
    _position ??= Offset(
      screenSize.width - 76,
      screenSize.height - 140,
    );

    // Keep position within screen bounds
    final clampedX = _position!.dx.clamp(16.0, screenSize.width - 72.0);
    final clampedY = _position!.dy.clamp(60.0, screenSize.height - 120.0);
    final bubbleOffset = Offset(clampedX, clampedY);

    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,

        // Modal backdrop when expanded
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = false),
              child: Container(
                color: Colors.black45,
              ),
            ),
          ),

        // Expanded Floating Window
        if (_isExpanded)
          Center(
            child: FloatingTaskPanel(
              onClose: () => setState(() => _isExpanded = false),
            ),
          ),

        // Collapsed Round Draggable Floating Bubble
        if (!_isExpanded)
          Positioned(
            left: bubbleOffset.dx,
            top: bubbleOffset.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    bubbleOffset.dx + details.delta.dx,
                    bubbleOffset.dy + details.delta.dy,
                  );
                });
              },
              onTap: () {
                setState(() => _isExpanded = true);
              },
              child: Material(
                elevation: 8,
                shape: const CircleBorder(),
                color: theme.colorScheme.primary,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // SyncTask Logo inside round bubble
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      // Pending Count Badge
                      if (pendingCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              pendingCount > 99 ? '99+' : '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
