// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'dart:math' as math;

import 'package:activation_companion/ui/monospace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A key returned by Magic Lane Services, to carry back to the device.
class IssuedKeyCard extends StatelessWidget {
  const IssuedKeyCard({super.key, required this.issuedKey, required this.label, required this.instructions});

  final String issuedKey;
  final String label;
  final String instructions;

  // Offline keys are 20 characters typed by hand, so they are shown in groups of 4, with a note that the device
  // takes them without the spaces. Copy key copies the key itself, without the spaces.
  static String _grouped(String key) =>
      [for (var start = 0; start < key.length; start += 4) key.substring(start, math.min(start + 4, key.length))]
          .join(' ');

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: issuedKey));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Key copied')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                _grouped(issuedKey),
                maxLines: 1,
                style: textTheme.headlineSmall?.copyWith(fontFamily: monospaceFontFamily, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 12),
            Text(instructions, style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Enter it as one string of ${issuedKey.length} characters, without the spaces. '
              'Upper and lower case letters are different.',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy key'),
              onPressed: () => _copy(context),
            ),
          ],
        ),
      ),
    );
  }
}
