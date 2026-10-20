// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/bloc/key_request/key_request_bloc.dart';
import 'package:activation_companion/client/activation_service_client.dart';
import 'package:activation_companion/ui/widgets/key_request_view.dart';
import 'package:activation_companion/ui/widgets/page_body.dart';
import 'package:activation_companion/ui/widgets/request_blob_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Exchanges a request blob for an offline activation or deactivation key. The device produces the blob with
/// getOfflineActivationRequestBlob() / getOfflineDeactivationRequestBlob(), or activate() / deactivate() reporting
/// KRequired on SDK builds delivered with license keys, and takes the key in completeOfflineActivation() /
/// completeOfflineDeactivation(). Producing a deactivation blob deactivates the device at once.
class OfflineKeyPage extends StatelessWidget {
  const OfflineKeyPage._({
    required this.title,
    required this.introduction,
    required this.keyLabel,
    required this.keyInstructions,
    required this.keyRequested,
  });

  static Route<void> activationRoute() => _route(
    OfflineKeyPage._(
      title: 'Activate a device',
      introduction: 'Start the offline activation on the device, then scan the QR code it shows or paste its text.',
      keyLabel: 'Activation key',
      keyInstructions: 'Type this key into the device to complete the activation.',
      keyRequested: OfflineActivationKeyRequested.new,
    ),
  );

  static Route<void> deactivationRoute() => _route(
    OfflineKeyPage._(
      title: 'Deactivate a device',
      introduction:
          'Start the offline deactivation on the device, then scan the QR code it shows or paste its text. '
          'The device is no longer activated from that moment. Its license can be used on another device '
          'as soon as you get the key.',
      keyLabel: 'Deactivation key',
      keyInstructions: 'Type this key into the device to complete the deactivation.',
      keyRequested: OfflineDeactivationKeyRequested.new,
    ),
  );

  static Route<void> _route(OfflineKeyPage page) => MaterialPageRoute(
    builder: (context) =>
        BlocProvider(create: (context) => KeyRequestBloc(context.read<ActivationServiceClient>()), child: page),
  );

  final String title;
  final String introduction;
  final String keyLabel;
  final String keyInstructions;
  final KeyRequestEvent Function(String requestBlob) keyRequested;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageBody(
        children: [
          Text(introduction),
          const SizedBox(height: 16),
          KeyRequestView(
            keyLabel: keyLabel,
            keyInstructions: keyInstructions,
            idle: RequestBlobInput(onSubmitted: (blob) => context.read<KeyRequestBloc>().add(keyRequested(blob))),
          ),
        ],
      ),
    );
  }
}
