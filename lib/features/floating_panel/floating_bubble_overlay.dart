import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synctask/features/floating_panel/floating_task_panel.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/widgets/media_deck_popup.dart';
import 'package:synctask/features/settings/settings_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';

class FloatingBubbleOverlay extends StatefulWidget {
  final Widget child;

  const FloatingBubbleOverlay({super.key, required this.child});

  @override
  State<FloatingBubbleOverlay> createState() => _FloatingBubbleOverlayState();
}

class _FloatingBubbleOverlayState extends State<FloatingBubbleOverlay>
    with TickerProviderStateMixin {
  final ValueNotifier<Offset> _bubblePosition = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> _panelPosition = ValueNotifier(Offset.zero);
  bool _initialized = false;
  bool _isExpanded = false;
  bool _isDraggingBubble = false;
  Offset _panStartPoint = Offset.zero;

  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _deckDismissTimer;
  StreamSubscription? _mediaSubscription;

  void _openPanel(Size screenSize, double panelWidth, double panelHeight) {
    final bubblePos = _bubblePosition.value;
    final initialPanelX = (bubblePos.dx - panelWidth + 56.0).clamp(
      12.0,
      (screenSize.width - panelWidth - 12.0).clamp(12.0, screenSize.width),
    );
    final initialPanelY = (bubblePos.dy - panelHeight + 56.0).clamp(
      36.0,
      (screenSize.height - panelHeight - 16.0).clamp(36.0, screenSize.height),
    );
    _panelPosition.value = Offset(initialPanelX, initialPanelY);
    setState(() => _isExpanded = true);
  }

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_snapAnimation != null) {
          _bubblePosition.value = _snapAnimation!.value;
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 0.95).chain(CurveTween(curve: Curves.easeInOutQuad)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeInQuad)), weight: 30),
    ]).animate(_pulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaCtrl = context.read<MediaTransferController?>();
      if (mediaCtrl != null) {
        _mediaSubscription = mediaCtrl.onMediaReceived.listen((item) {
          _pulseController.forward(from: 0.0);
          _deckDismissTimer?.cancel();
          _deckDismissTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) {
              mediaCtrl.dismissRecentMedia();
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    _deckDismissTimer?.cancel();
    _pulseController.dispose();
    _snapController.dispose();
    _bubblePosition.dispose();
    _panelPosition.dispose();
    super.dispose();
  }

  void _snapToEdge(Size screenSize) {
    final cur = _bubblePosition.value;
    final targetX = cur.dx < (screenSize.width / 2)
        ? 16.0
        : (screenSize.width - 72.0);
    final target = Offset(targetX, cur.dy);

    _snapAnimation = Tween<Offset>(
      begin: cur,
      end: target,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    _snapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    if (!settings.isFloatingBubbleEnabled) {
      return widget.child;
    }

    final taskController = context.watch<TaskController>();
    final pendingCount =
        taskController.tasks.where((t) => !t.completed).length;

    final mediaCtrl = context.watch<MediaTransferController?>();
    final recentMedia = mediaCtrl?.recentReceived ?? [];

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Position bubble higher up (middle right) so it NEVER overlaps "+ New Task" FAB!
    if (!_initialized) {
      _bubblePosition.value = Offset(
        screenSize.width - 72.0,
        (screenSize.height * 0.42).clamp(100.0, screenSize.height - 180.0),
      );
      _initialized = true;
    }

    const panelWidth = 340.0;
    const panelHeight = 480.0;
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Base App (Never rebuilds during touch drags!)
        widget.child,

        // Modal backdrop and expanded Floating Window
        if (_isExpanded)
          Positioned.fill(
            child: Stack(
              children: [
                // Backdrop
                GestureDetector(
                  onTap: () {
                    setState(() => _isExpanded = false);
                  },
                  child: Container(color: Colors.black45),
                ),

                // Draggable FloatingTaskPanel
                ValueListenableBuilder<Offset>(
                  valueListenable: _panelPosition,
                  builder: (context, panelPos, panelChild) {
                    return Positioned(
                      left: panelPos.dx,
                      top: panelPos.dy,
                      child: panelChild!,
                    );
                  },
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final cur = _panelPosition.value;
                        final newX = (cur.dx + details.delta.dx).clamp(
                          12.0,
                          (screenSize.width - panelWidth - 12.0).clamp(12.0, screenSize.width),
                        );
                        final newY = (cur.dy + details.delta.dy).clamp(
                          36.0,
                          (screenSize.height - panelHeight - 16.0).clamp(36.0, screenSize.height),
                        );
                        _panelPosition.value = Offset(newX, newY);
                      },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.85 + (0.15 * val),
                              child: child,
                            ),
                          );
                        },
                        child: FloatingTaskPanel(
                          width: panelWidth,
                          height: panelHeight,
                          onClose: () {
                            setState(() => _isExpanded = false);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Collapsed Round Draggable Floating Bubble + Deck-of-Cards Popup
        if (!_isExpanded)
          ValueListenableBuilder<Offset>(
            valueListenable: _bubblePosition,
            builder: (context, pos, child) {
              final isRightSide = pos.dx > (screenSize.width / 2);
              final deckLeft = isRightSide ? (pos.dx - 100.0) : (pos.dx + 62.0);
              final deckTop = (pos.dy - 30.0).clamp(20.0, screenSize.height - 130.0);

              return Stack(
                children: [
                  // Deck-of-Cards Popup when media arrives
                  if (recentMedia.isNotEmpty)
                    Positioned(
                      left: deckLeft,
                      top: deckTop,
                      child: MediaDeckBubblePopup(
                        items: recentMedia,
                        onDismiss: () => mediaCtrl?.dismissRecentMedia(),
                        onTapDeck: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => DeckOfCardsGalleryModal(
                              items: recentMedia,
                              onDismissAll: () => mediaCtrl?.dismissRecentMedia(),
                            ),
                          );
                        },
                      ),
                    ),

                  // Bubble Position
                  Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: child!,
                  ),
                ],
              );
            },
            child: RepaintBoundary(
              child: GestureDetector(
                onPanStart: (details) {
                  _snapController.stop();
                  _panStartPoint = details.globalPosition;
                  _isDraggingBubble = false;
                },
                onPanUpdate: (details) {
                  if (!_isDraggingBubble && (details.globalPosition - _panStartPoint).distance > 8.0) {
                    _isDraggingBubble = true;
                  }
                  if (_isDraggingBubble) {
                    final cur = _bubblePosition.value;
                    final newX = (cur.dx + details.delta.dx).clamp(10.0, screenSize.width - 66.0);
                    final newY = (cur.dy + details.delta.dy).clamp(40.0, screenSize.height - 110.0);
                    _bubblePosition.value = Offset(newX, newY);
                  }
                },
                onPanEnd: (_) {
                  if (_isDraggingBubble) {
                    _snapToEdge(screenSize);
                  } else {
                    _openPanel(screenSize, panelWidth, panelHeight);
                  }
                },
                onTap: () {
                  _openPanel(screenSize, panelWidth, panelHeight);
                },
                onLongPress: () {
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: theme.colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (sheetContext) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.dashboard_customize_outlined),
                                title: const Text('Open Tasks Panel'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  setState(() => _isExpanded = true);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.visibility_off_outlined, color: Colors.redAccent),
                                title: const Text(
                                  'Hide Floating Bubble',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text('You can turn it back on anytime in Settings'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  context.read<SettingsController>().setFloatingBubbleEnabled(false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Floating bubble hidden. Re-enable anytime in Settings.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, bubbleChild) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: bubbleChild,
                    );
                  },
                  child: Material(
                    elevation: 8,
                    shape: const CircleBorder(),
                    color: Colors.white,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(0xFF185ABD).withValues(alpha: 0.18),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              width: 50,
                              height: 50,
                              fit: BoxFit.contain,
                            ),
                          ),
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
            ),
          ),
      ],
    );
  }
}
