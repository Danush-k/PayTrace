import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/qr_parser.dart';

/// QR Scanner screen — scans UPI QR codes (static & dynamic)
///
/// Flow:
/// 1. Opens camera with scanner overlay
/// 2. Detects and decodes QR code
/// 3. Parses UPI URI → extracts pa, pn, am, tn
/// 4. Returns [QrPaymentData] to calling screen
///
/// For **Static QR**: returns data with amount = null
/// For **Dynamic QR**: returns data with amount pre-filled
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasScanned = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final qrData = QrParser.parse(rawValue);

    if (qrData != null) {
      _hasScanned = true;
      Navigator.of(context).pop(qrData);
    } else {
      setState(() {
        _errorMessage = 'Not a valid UPI QR code. Please try again.';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _errorMessage = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded,
                color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _buildScannerOverlay(),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Point camera at a UPI QR code',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Supports Static & Dynamic UPI QR codes',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: _ScannerOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2.5;
    final right = left + scanAreaSize;
    final bottom = top + scanAreaSize;

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, top), bgPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, bottom, size.width, size.height), bgPaint);
    canvas.drawRect(Rect.fromLTRB(0, top, left, bottom), bgPaint);
    canvas.drawRect(Rect.fromLTRB(right, top, size.width, bottom), bgPaint);

    final bracketPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cl = 30.0;
    const r = 8.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cl)
        ..lineTo(left, top + r)
        ..quadraticBezierTo(left, top, left + r, top)
        ..lineTo(left + cl, top),
      bracketPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(right - cl, top)
        ..lineTo(right - r, top)
        ..quadraticBezierTo(right, top, right, top + r)
        ..lineTo(right, top + cl),
      bracketPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cl)
        ..lineTo(left, bottom - r)
        ..quadraticBezierTo(left, bottom, left + r, bottom)
        ..lineTo(left + cl, bottom),
      bracketPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(right - cl, bottom)
        ..lineTo(right - r, bottom)
        ..quadraticBezierTo(right, bottom, right, bottom - r)
        ..lineTo(right, bottom - cl),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
