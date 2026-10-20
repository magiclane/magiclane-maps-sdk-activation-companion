// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/client/activation_service_client.dart';
import 'package:activation_companion/models/activation_service_exception.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'key_request_event.dart';
part 'key_request_state.dart';

/// Asks Magic Lane Services for one key: an offline activation or deactivation key. The first service URL
/// that may have processed a request is kept, and every later request of this bloc goes to it.
class KeyRequestBloc extends Bloc<KeyRequestEvent, KeyRequestState> {
  KeyRequestBloc(this._client) : super(const KeyRequestIdle()) {
    on<OfflineActivationKeyRequested>(_onOfflineActivationKeyRequested);
    on<OfflineDeactivationKeyRequested>(_onOfflineDeactivationKeyRequested);
    on<KeyRequestReset>(_onKeyRequestReset);
  }

  static final _whitespace = RegExp(r'\s');

  // Blobs copied from a terminal or a document often carry line breaks.
  static String _withoutWhitespace(String requestBlob) => requestBlob.replaceAll(_whitespace, '');

  final ActivationServiceClient _client;
  String? _serviceUrl;

  Future<void> _onOfflineActivationKeyRequested(OfflineActivationKeyRequested event, Emitter<KeyRequestState> emit) {
    final requestBlob = _withoutWhitespace(event.requestBlob);
    return _request(emit, (serviceUrl) => _client.requestOfflineActivationKey(serviceUrl, requestBlob));
  }

  Future<void> _onOfflineDeactivationKeyRequested(
    OfflineDeactivationKeyRequested event,
    Emitter<KeyRequestState> emit,
  ) {
    final requestBlob = _withoutWhitespace(event.requestBlob);
    return _request(emit, (serviceUrl) => _client.requestOfflineDeactivationKey(serviceUrl, requestBlob));
  }

  void _onKeyRequestReset(KeyRequestReset event, Emitter<KeyRequestState> emit) => emit(const KeyRequestIdle());

  // A request made while another one runs (double tap, the same QR code detected again) is dropped.
  Future<void> _request(Emitter<KeyRequestState> emit, Future<String> Function(String serviceUrl) send) async {
    if (state is KeyRequestInProgress) return;
    emit(const KeyRequestInProgress());
    final String key;
    try {
      key = await _sendToServiceUrl(send);
    } on ActivationServiceException catch (error) {
      emit(KeyRequestFailure(error));
      return;
    } catch (error, stackTrace) {
      // Any other error is a bug: it still ends the request, and is reported to onError.
      emit(const KeyRequestFailure(ActivationServiceException('The key could not be requested. Try again.')));
      addError(error, stackTrace);
      return;
    }
    emit(KeyRequestSuccess(key));
  }

  // The listed URLs are tried in order, skipping one that certainly did not process the request. The first URL
  // that may have processed it is kept, whatever it said, so a retry of the same request never reaches a second
  // URL. A later failure of that URL is reported rather than avoided.
  Future<String> _sendToServiceUrl(Future<String> Function(String serviceUrl) send) async {
    if (_serviceUrl case final serviceUrl?) return send(serviceUrl);
    final serviceUrls = await _client.fetchServiceUrls();
    for (final (index, serviceUrl) in serviceUrls.indexed) {
      try {
        final key = await send(serviceUrl);
        _serviceUrl = serviceUrl;
        return key;
      } on ActivationServiceException catch (error) {
        if (!error.isUnprocessed) {
          _serviceUrl = serviceUrl;
          rethrow;
        }
        if (index == serviceUrls.length - 1) rethrow;
      }
    }
    throw const ActivationServiceException('Magic Lane Services are not available right now. Try again later.');
  }
}
