// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

part of 'key_request_bloc.dart';

sealed class KeyRequestState extends Equatable {
  const KeyRequestState();

  @override
  List<Object?> get props => [];
}

final class KeyRequestIdle extends KeyRequestState {
  const KeyRequestIdle();
}

final class KeyRequestInProgress extends KeyRequestState {
  const KeyRequestInProgress();
}

final class KeyRequestSuccess extends KeyRequestState {
  const KeyRequestSuccess(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

final class KeyRequestFailure extends KeyRequestState {
  const KeyRequestFailure(this.error);

  final ActivationServiceException error;

  @override
  List<Object?> get props => [error];
}
