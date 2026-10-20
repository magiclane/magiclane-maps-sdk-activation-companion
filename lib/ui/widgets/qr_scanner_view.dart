// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reads the QR code shown by the device with the camera or, on Android and iOS, from a picture of it.
/// The scanner asks for the camera permission itself; picking a picture needs no permission.
class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  static String? _textOf(BarcodeCapture? capture) =>
      capture?.barcodes.map((barcode) => barcode.rawValue).nonNulls.where((value) => value.isNotEmpty).firstOrNull;

  Future<void> _scanPicture() async {
    final picture = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    if (picture == null) return;

    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(picture.path, formats: const [BarcodeFormat.qrCode]);
    } on MobileScannerBarcodeException {
      capture = null;
    }
    if (!mounted) return;

    if (_textOf(capture) case final text?) {
      widget.onDetected(text);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No QR code found in this picture.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_textOf(capture) case final text?) widget.onDetected(text);
              },
              errorBuilder: (context, error) => _ScannerError(error),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Point the camera at the QR code shown by the device.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        // Reading a picture is not supported by the scanner in the browser.
        if (!kIsWeb) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Scan from picture'),
            onPressed: _scanPicture,
          ),
        ],
      ],
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError(this.error);

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera access was denied. Allow it in the settings, or paste the text instead.',
      MobileScannerErrorCode.unsupported => 'No camera is available. Paste the text instead.',
      _ => 'The camera could not start. Paste the text instead.',
    };
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
