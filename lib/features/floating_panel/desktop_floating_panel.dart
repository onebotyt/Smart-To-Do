import 'package:flutter/material.dart';
import 'package:synctask/features/floating_panel/floating_task_panel.dart';

class DesktopFloatingPanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const DesktopFloatingPanel({
    super.key,
    required this.onClose,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: SizedBox.expand(
          child: FloatingTaskPanel(
            width: double.infinity,
            height: double.infinity,
            onClose: onClose,
            onExpand: onExpand,
          ),
        ),
      ),
    );
  }
}
