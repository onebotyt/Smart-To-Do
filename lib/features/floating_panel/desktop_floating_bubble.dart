import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../platform/window_service.dart';
import '../settings/settings_controller.dart';
import '../tasks/task_controller.dart';

class DesktopFloatingBubble extends StatefulWidget {
  const DesktopFloatingBubble({super.key});

  @override
  State<DesktopFloatingBubble> createState() => _DesktopFloatingBubbleState();
}

class _DesktopFloatingBubbleState extends State<DesktopFloatingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final taskController = context.watch<TaskController>();
    final pendingCount = taskController.tasks.where((t) => !t.completed).length;
    final color = settings.themeSeedColor;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onPanStart: (_) {
              PlatformWindowService.startDragging();
            },
            onTap: () {
              PlatformWindowService.setWindowMode(AppWindowMode.panel);
            },
            onSecondaryTapUp: (details) {
              _showContextMenu(context, details.globalPosition);
            },
            child: Tooltip(
              message: 'SyncTask • $pendingCount pending\nClick: open panel • Right-click: options / exit • Drag to move',
              waitDuration: const Duration(milliseconds: 350),
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  final scale = _isHovered ? 1.06 : _scaleAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.25) ?? color,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: _isHovered ? 0.6 : 0.4),
                        blurRadius: _isHovered ? 12 : 8,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2.2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Center Logo / Checkmark Icon
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 34,
                      ),

                      // Pending tasks badge
                      if (pendingCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                pendingCount > 99 ? '99+' : '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Quick close (X) button on hover
                      if (_isHovered)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Listener(
                            onPointerDown: (_) {
                              PlatformWindowService.setWindowMode(AppWindowMode.normal);
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message: 'Close bubble (return to full app)',
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.4),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
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
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          onTap: () => PlatformWindowService.setWindowMode(AppWindowMode.panel),
          child: const Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 18),
              SizedBox(width: 8),
              Text('Open Floating Panel'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => PlatformWindowService.setWindowMode(AppWindowMode.normal),
          child: const Row(
            children: [
              Icon(Icons.open_in_full_rounded, size: 18),
              SizedBox(width: 8),
              Text('Close Bubble (Open Full App)'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => PlatformWindowService.exitApp(),
          child: const Row(
            children: [
              Icon(Icons.power_settings_new_rounded, size: 18, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Exit SyncTask Completely', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }
}
