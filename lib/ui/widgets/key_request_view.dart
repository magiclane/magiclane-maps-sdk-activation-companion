// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/bloc/key_request/key_request_bloc.dart';
import 'package:activation_companion/models/activation_service_exception.dart';
import 'package:activation_companion/ui/widgets/issued_key_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows [idle] until a key is requested, then the progress, the issued key or the failure.
class KeyRequestView extends StatelessWidget {
  const KeyRequestView({super.key, required this.idle, required this.keyLabel, required this.keyInstructions});

  final Widget idle;
  final String keyLabel;
  final String keyInstructions;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeyRequestBloc, KeyRequestState>(
      builder: (context, state) => switch (state) {
        KeyRequestIdle() => idle,
        KeyRequestInProgress() => const _Progress(),
        KeyRequestSuccess(:final key) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IssuedKeyCard(issuedKey: key, label: keyLabel, instructions: keyInstructions),
            const SizedBox(height: 8),
            const _StartOverButton(label: 'Start over'),
          ],
        ),
        KeyRequestFailure(:final error) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FailureCard(error),
            const SizedBox(height: 8),
            const _StartOverButton(label: 'Try again'),
          ],
        ),
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Getting the key…')]),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard(this.error);

  final ActivationServiceException error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
        title: Text(error.message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}

class _StartOverButton extends StatelessWidget {
  const _StartOverButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.refresh),
      label: Text(label),
      onPressed: () => context.read<KeyRequestBloc>().add(const KeyRequestReset()),
    );
  }
}
