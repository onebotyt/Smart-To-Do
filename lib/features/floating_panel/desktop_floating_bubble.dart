import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../platform/window_service.dart';
import '../media_transfer/media_transfer_controller.dart';
import '../media_transfer/models/media_transfer.dart';
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
  Offset _pointerDownPos = Offset.zero;
  bool _didDrag = false;
  StreamSubscription? _mediaSub;
  MediaTransferItem? _recentMedia;
  Timer? _recentDismissTimer;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaCtrl = context.read<MediaTransferController?>();
      if (mediaCtrl != null) {
        _mediaSub = mediaCtrl.onMediaReceived.listen((item) {
          if (mounted) {
            setState(() => _recentMedia = item);
            _pulseController.duration = const Duration(milliseconds: 500);
            _pulseController.repeat(reverse: true);
            _recentDismissTimer?.cancel();
            _recentDismissTimer = Timer(const Duration(seconds: 6), () {
              if (mounted) {
                setState(() => _recentMedia = null);
                _pulseController.duration = const Duration(milliseconds: 2400);
                _pulseController.repeat(reverse: true);
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    _recentDismissTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final taskController = context.watch<TaskController>();
    final pendingCount = taskController.tasks.where((t) => !t.completed).length;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Listener(
            onPointerDown: (event) {
              _pointerDownPos = event.position;
              _didDrag = false;
            },
            onPointerMove: (event) {
              if (!_didDrag && (event.position - _pointerDownPos).distance > 6.0) {
                _didDrag = true;
                PlatformWindowService.startDragging();
              }
            },
            onPointerUp: (event) {
              // Single click without drag: immediately open the floating panel!
              if (!_didDrag) {
                PlatformWindowService.setWindowMode(AppWindowMode.panel);
              }
            },
            child: GestureDetector(
              onTap: () {
                if (!_didDrag) {
                  PlatformWindowService.setWindowMode(AppWindowMode.panel);
                }
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
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: _isHovered ? 0.22 : 0.14),
                          blurRadius: _isHovered ? 14 : 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: const Color(0xFF185ABD).withValues(alpha: _isHovered ? 0.25 : 0.15),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Center Content: Either Recent Image Thumbnail or Checkmark Logo
                        ClipOval(
                          child: (_recentMedia != null &&
                                  File(_recentMedia!.filePath).existsSync() &&
                                  _isImageFile(_recentMedia!.filePath))
                              ? Image.file(
                                  File(_recentMedia!.filePath),
                                  width: 66,
                                  height: 66,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/logo.png',
                                  width: 66,
                                  height: 66,
                                  fit: BoxFit.contain,
                                ),
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
                      ],
                    ),
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
