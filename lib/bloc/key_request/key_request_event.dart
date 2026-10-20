// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

part of 'key_request_bloc.dart';

sealed class KeyRequestEvent extends Equatable {
  const KeyRequestEvent();

  @override
  List<Object?> get props => [];
}

/// An activation request blob was scanned or pasted.
final class OfflineActivationKeyRequested extends KeyRequestEvent {
  const OfflineActivationKeyRequested(this.requestBlob);

  final String requestBlob;

  @override
  List<Object?> get props => [requestBlob];
}

/// A deactivation request blob was scanned or pasted.
final class OfflineDeactivationKeyRequested extends KeyRequestEvent {
  const OfflineDeactivationKeyRequested(this.requestBlob);

  final String requestBlob;

  @override
  List<Object?> get props => [requestBlob];
}

/// The result was dismissed, to process another request.
final class KeyRequestReset extends KeyRequestEvent {
  const KeyRequestReset();
}
