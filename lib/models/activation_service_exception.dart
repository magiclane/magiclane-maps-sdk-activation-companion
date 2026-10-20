// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:equatable/equatable.dart';

/// A failed exchange with Magic Lane Services. [statusCode] is null when no answer was received.
/// [isUnprocessed] is true when the service certainly did not process the request: no connection was made, or a
/// gateway answered that the service is unavailable. Such a request can be sent to another URL without being
/// processed twice.
class ActivationServiceException extends Equatable implements Exception {
  const ActivationServiceException(this.message, {this.statusCode, this.isUnprocessed = false});

  final String message;
  final int? statusCode;
  final bool isUnprocessed;

  @override
  List<Object?> get props => [message, statusCode, isUnprocessed];
}
