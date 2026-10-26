import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasDetected = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        try {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic> &&
              data['type'] == 'synctask_pair' &&
              data.containsKey('ip') &&
              data.containsKey('pin')) {
            _hasDetected = true;
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(data);
            return;
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Pairing QR Code'),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _controller.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout viewfinder
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Theme.of(context).colorScheme.primary,
                borderRadius: 16,
                borderLength: 32,
                borderWidth: 4,
                cutOutSize: 260,
              ),
            ),
          ),

          // Bottom Hint
          Positioned(
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point camera at QR code on your PC or phone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.blue,
    this.borderWidth = 4.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 16.0,
    this.borderLength = 32.0,
    this.cutOutSize = 250.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final width = cutOutSize;
    final height = cutOutSize;
    final left = rect.left + (rect.width - width) / 2;
    final top = rect.top + (rect.height - height) / 2;

    return Path()
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = cutOutSize;
    final height = cutOutSize;
    final left = rect.left + (rect.width - width) / 2;
    final top = rect.top + (rect.height - height) / 2;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final outerPath = Path()..addRect(rect);
    final innerPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          Radius.circular(borderRadius),
        ),
      );

    final cutPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(cutPath, backgroundPaint);

    // Draw Corner Brackets
    // Top-left
    canvas.drawLine(
      Offset(left, top + borderLength),
      Offset(left, top + borderRadius),
      boxPaint,
    );
    canvas.drawLine(
      Offset(left + borderRadius, top),
      Offset(left + borderLength, top),
      boxPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(left, top, borderRadius * 2, borderRadius * 2),
      3.14159,
      1.5708,
      false,
      boxPaint,
    );

    // Top-right
    final right = left + width;
    canvas.drawLine(
      Offset(right - borderLength, top),
      Offset(right - borderRadius, top),
      boxPaint,
    );
    canvas.drawLine(
      Offset(right, top + borderRadius),
      Offset(right, top + borderLength),
      boxPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(right - borderRadius * 2, top, borderRadius * 2, borderRadius * 2),
      -1.5708,
      1.5708,
      false,
      boxPaint,
    );

    // Bottom-left
    final bottom = top + height;
    canvas.drawLine(
      Offset(left, bottom - borderLength),
      Offset(left, bottom - borderRadius),
      boxPaint,
    );
    canvas.drawLine(
      Offset(left + borderRadius, bottom),
      Offset(left + borderLength, bottom),
      boxPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(left, bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2),
      1.5708,
      1.5708,
      false,
      boxPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(right - borderLength, bottom),
      Offset(right - borderRadius, bottom),
      boxPaint,
    );
    canvas.drawLine(
      Offset(right, bottom - borderLength),
      Offset(right, bottom - borderRadius),
      boxPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(right - borderRadius * 2, bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2),
      0,
      1.5708,
      false,
      boxPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
