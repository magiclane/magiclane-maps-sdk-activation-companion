// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/ui/monospace.dart';
import 'package:activation_companion/ui/widgets/qr_scanner_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _InputMode { scan, paste }

/// Takes the request blob shown by the device, either by scanning its QR code or as pasted text.
class RequestBlobInput extends StatefulWidget {
  const RequestBlobInput({super.key, required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<RequestBlobInput> createState() => _RequestBlobInputState();
}

class _RequestBlobInputState extends State<RequestBlobInput> {
  final _blob = TextEditingController();

  // Scanning suits phones (in the browser too, where the target platform is the phone's OS);
  // pasting suits desktops.
  var _mode = switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => _InputMode.scan,
    _ => _InputMode.paste,
  };

  @override
  void dispose() {
    _blob.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final text?) _blob.text = text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_InputMode>(
          segments: const [
            ButtonSegment(value: _InputMode.scan, icon: Icon(Icons.qr_code_scanner), label: Text('Scan QR code')),
            ButtonSegment(value: _InputMode.paste, icon: Icon(Icons.content_paste), label: Text('Paste text')),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) => setState(() => _mode = selection.single),
        ),
        const SizedBox(height: 16),
        switch (_mode) {
          _InputMode.scan => QrScannerView(onDetected: widget.onSubmitted),
          _InputMode.paste => _buildPasteField(),
        },
      ],
    );
  }

  Widget _buildPasteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _blob,
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(fontFamily: monospaceFontFamily),
          decoration: InputDecoration(
            labelText: 'Request from the device',
            hintText: 'Paste the text shown by the device',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Paste from clipboard',
              icon: const Icon(Icons.content_paste),
              onPressed: _pasteFromClipboard,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: _blob,
          builder: (context, value, _) => FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Get key'),
            onPressed: value.text.trim().isEmpty ? null : () => widget.onSubmitted(value.text),
          ),
        ),
      ],
    );
  }
}
